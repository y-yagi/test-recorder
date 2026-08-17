require "test_recorder/recorders/in_process"
require "test_recorder/recorders/worker"

module TestRecorder
  class CdpRecorder
    RESCUED_ERRORS = [Recorders::Worker::Error].freeze

    class << self
      def recorder
        return @recorder if defined?(@recorder) && @recorder

        @recorder = build_recorder
      end

      def fallback(reason)
        warn "test-recorder: #{reason}, falling back to in-process recording" unless defined?(@warned) && @warned
        @warned = true
        @recorder = Recorders::InProcess.new
      end

      private

      def build_recorder
        return Recorders::InProcess.new unless TestRecorder.separate_process

        Recorders::Worker.new
      end
    end

    def initialize(enabled:)
      @enabled = enabled
      @started = nil
    end

    def start(page:, enabled: nil)
      enabled = @enabled if enabled.nil?
      @started = enabled
      return unless @started

      begin
        self.class.recorder.start(page: page)
      rescue *RESCUED_ERRORS => e
        self.class.fallback("#{e.class}: #{e.message}")
        self.class.recorder.start(page: page)
      end
    end

    def stop_and_discard
      return unless @started

      self.class.recorder.stop_and_discard
    rescue *RESCUED_ERRORS => e
      self.class.fallback("#{e.class}: #{e.message}")
    end

    def stop_and_save(filename)
      return "" unless @started

      self.class.recorder.stop_and_save(filename)
    rescue *RESCUED_ERRORS => e
      self.class.fallback("#{e.class}: #{e.message}")
      ""
    end
  end
end
