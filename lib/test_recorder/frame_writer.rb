require "test_recorder/matroska_writer"

module TestRecorder
  class FrameWriter
    # How long the last frame stays visible at the end of the video. A test usually fails some
    # time after the last repaint, and that last screen is the one worth looking at.
    MIN_LAST_FRAME_DURATION = 1.0
    MAX_LAST_FRAME_DURATION = 5.0

    def initialize(io)
      @container = MatroskaWriter.new(io)
      @first_frame_time = nil
      @last_frame = nil
      @last_write_at = nil
      @last_timestamp_ms = 0
      @duration = nil
      @frame_count = 0
      @finished = false
      # CDP dispatches every screencast frame event on its own thread, and `finish` can run on the
      # main thread while a frame is still in flight, so all access to the state above and to the
      # container is serialized through this.
      @mutex = Mutex.new
    end

    def empty?
      @last_frame.nil?
    end

    # How many seconds the finished video should run for. ffmpeg does not reliably infer this from
    # the container alone, so `stop_and_save` passes it to ffmpeg explicitly. Only meaningful after
    # `finish` has run.
    attr_reader :duration

    # Chrome sends a frame as soon as the screencast starts, so a test that fails before it draws
    # anything still leaves behind the one frame of the blank page it started on. Callers use this
    # to tell that apart from a real recording.
    attr_reader :frame_count

    def write(frame, time)
      @mutex.synchronize do
        return if @finished

        @first_frame_time ||= time
        write_at(frame, time)
        @last_frame = frame
        @last_write_at = monotonic_time
        @frame_count += 1
      end
    end

    # Repeats the last frame at the end of the recording so that it stays on screen, and so that
    # the video covers the time between the last repaint and the end of the test. That interval is
    # measured with the monotonic clock, so a wall clock adjustment cannot stretch or shrink it.
    def finish
      @mutex.synchronize do
        return if @finished

        @finished = true
        return if empty?

        elapsed = (monotonic_time - @last_write_at).clamp(MIN_LAST_FRAME_DURATION, MAX_LAST_FRAME_DURATION)
        write_ms(@last_frame, @last_timestamp_ms + (elapsed * 1000).round)
        @duration = @last_timestamp_ms / 1000.0
      end
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def write_at(frame, time)
      write_ms(frame, ((time - @first_frame_time) * 1000).round)
    end

    def write_ms(frame, timestamp_ms)
      timestamp_ms = [timestamp_ms, @last_timestamp_ms].max
      @container.write_frame(frame, timestamp_ms)
      @last_timestamp_ms = timestamp_ms
    end
  end
end
