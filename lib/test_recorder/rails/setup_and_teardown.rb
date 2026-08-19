module TestRecorder
  module Rails
    module SetupAndTeardown
      def before_setup
        @cdp_recorder = TestRecorder::CdpRecorder.new(enabled: TestRecorder.enabled?)
        enabled = respond_to?(:metadata) ? metadata[:test_recorder] : nil
        @cdp_recorder.start(page: page, enabled: enabled)

        super
      end

      def before_teardown
        if failures.any? { |failure| !failure.is_a?(Minitest::Skip) }
          video_path = @cdp_recorder.stop_and_save("failures_#{TestRecorder.sanitize_filename(self.name)}.webm")
          puts "[Video]: #{video_path}" if File.exist?(video_path)
        else
          @cdp_recorder.stop_and_discard
        end
      ensure
        super
      end
    end
  end
end
