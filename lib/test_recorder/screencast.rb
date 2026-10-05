require "base64"
require "tempfile"

require "test_recorder/frame_writer"

module TestRecorder
  # Records with `Page.startScreencast`, which sends a JPEG for every repaint, and has ffmpeg
  # encode them into a video afterwards. This is the fallback for Chrome versions without
  # `Page.startScreenRecording`.
  class Screencast
    EXTENSION = ".webm".freeze

    FFMPEG_ENCODE_OPTIONS = %w[-y -an -c:v vp8 -qmin 0 -qmax 50 -crf 8 -deadline realtime -speed 8 -b:v 1M -threads 1].freeze

    # ffmpeg's -t treats the given duration as an exclusive cutoff, dropping the very frame that
    # marks the video's real length if it lands exactly on it. This nudges -t just past that frame
    # so it is kept, without adding a duration long enough to be noticeable.
    FFMPEG_DURATION_SLACK_S = 0.01

    Record = Struct.new(:page, :io, :last_metadata_time, :last_metadata_received_at)

    class << self
      def record(devtools)
        records[devtools] ||= begin
          page = devtools.page
          page.enable

          record = Record.new(page)
          page.on(:screencast_frame) do |event|
            write_frame(record, event)
            record.page.screencast_frame_ack(session_id: event["sessionId"])
          end
          record
        end
      end

      private

      def write_frame(record, event)
        record.io&.write(Base64.decode64(event["data"]), frame_time(record, event))
      rescue IOError
        # A frame can still arrive after the recording was stopped and the file was closed.
      rescue => e
        warn "[TestRecorder] Failed to write a screencast frame: #{e.class}: #{e.message}"
      end

      # `metadata.timestamp` is the wall clock time of the frame swap, in seconds, on the browser's
      # clock. The protocol marks it optional, so when it is missing, estimate it from the last
      # frame that did carry one plus how much monotonic time has passed since. Falling back to
      # this process's own wall clock instead would silently distort pacing whenever the browser
      # runs on a different host than the driver, since the two wall clocks are not guaranteed to
      # agree.
      def frame_time(record, event)
        metadata = event["metadata"]
        timestamp = metadata && metadata["timestamp"]

        if timestamp
          record.last_metadata_time = timestamp
          record.last_metadata_received_at = monotonic_time
          timestamp
        elsif record.last_metadata_time
          record.last_metadata_time + (monotonic_time - record.last_metadata_received_at)
        else
          Time.now.to_f
        end
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def records
        @records ||= {}.compare_by_identity
      end
    end

    def initialize(browser)
      @browser = browser
    end

    def extension
      EXTENSION
    end

    def start
      @tmp_video = Tempfile.new(["testrecorder", ".mkv"])
      @tmp_video.binmode

      @record = self.class.record(@browser.devtools)
      @frame_writer = FrameWriter.new(@tmp_video)
      @record.io = @frame_writer

      @record.page.start_screencast(format: "jpeg", quality: TestRecorder.jpeg_quality, max_width: TestRecorder.max_dimension, max_height: TestRecorder.max_dimension, every_nth_frame: TestRecorder.every_nth_frame)
    end

    def stop_and_discard
      @record.io = nil
      @record.page.stop_screencast
      @tmp_video.close!
    end

    # Returns true when the video was written to `video_path`.
    def stop_and_save(video_path)
      @record.io = nil
      @record.page.stop_screencast
      @frame_writer.finish
      @tmp_video.flush

      # Chrome sends a frame as soon as the screencast starts, so a test that fails
      # before it draws anything still leaves behind the one frame of the blank page
      # it started on.
      if @frame_writer.frame_count < 2
        warn "[TestRecorder] The screencast captured no page updates, so no video was saved."
        @tmp_video.close!
        return false
      end

      # Each frame carries its own timestamp in the Matroska stream, so ffmpeg knows how long to
      # hold it and duplicates frames to reach the constant output frame rate on its own. Without a
      # known end, though, ffmpeg pads however long it likes past the last real timestamp, so -t
      # caps the output at the video's real duration explicitly.
      duration = @frame_writer.duration + FFMPEG_DURATION_SLACK_S
      result = system("ffmpeg", "-loglevel", "error", "-f", "matroska", "-i", @tmp_video.path, "-t", duration.to_s, "-r", TestRecorder.frame_rate.to_s, *FFMPEG_ENCODE_OPTIONS, video_path)

      @tmp_video.close!

      if result.nil?
        warn "[TestRecorder] Failed to execute ffmpeg. Please make sure that FFmpeg is installed."
        return false
      elsif !result
        warn "[TestRecorder] ffmpeg failed to encode #{video_path}."
        return false
      end

      true
    end
  end
end
