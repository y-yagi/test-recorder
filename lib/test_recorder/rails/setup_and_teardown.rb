require "fileutils"

module TestRecorder
  module Rails
    module SetupAndTeardown
      def before_setup
        @cdp_recorder = TestRecorder::CdpRecorder.new(enabled: true)
        @cdp_recorder.start(page: page)

        super
      end

      def before_teardown
        if failures.empty?
          @cdp_recorder.stop_and_discard
        else
          video_path = @cdp_recorder.stop_and_save("failures_#{self.name}.mp4")
          puts "[Video]: #{video_path}" if File.exist?(video_path)
        end
      ensure
        super
      end
    end
  end
end
