module TestRecorder
  # Works out when each screencast frame was captured. Both the in-process recorder and the worker
  # process receive frames, so both keep one of these per CDP connection.
  class FrameClock
    def initialize
      @last_metadata_time = nil
      @last_metadata_received_at = nil
    end

    # `metadata.timestamp` is the wall clock time of the frame swap, in seconds, on the browser's
    # clock. The protocol marks it optional, so when it is missing, estimate it from the last
    # frame that did carry one plus how much monotonic time has passed since. Falling back to
    # this process's own wall clock instead would silently distort pacing whenever the browser
    # runs on a different host than the driver, since the two wall clocks are not guaranteed to
    # agree.
    def frame_time(params)
      metadata = params["metadata"]
      timestamp = metadata && metadata["timestamp"]

      if timestamp
        @last_metadata_time = timestamp
        @last_metadata_received_at = monotonic_time
        timestamp
      elsif @last_metadata_time
        @last_metadata_time + (monotonic_time - @last_metadata_received_at)
      else
        Time.now.to_f
      end
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
