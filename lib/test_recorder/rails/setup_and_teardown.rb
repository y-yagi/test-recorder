require "headless"
require "fileutils"

module TestRecorder
  module Rails
    module SetupAndTeardown
      attr_reader :video_dir, :headless

      def before_setup
        return super if record_disabled?

        @video_dir = ::Rails.root.join("tmp", "videos")
        FileUtils.mkdir_p(video_dir)

        # TODO: Allow configuring parameters.
        @headless = Headless.new(video: { provider: :ffmpeg, codec: :libx264, extra: %w(-preset ultrafast) })
        headless.start
        headless.video.start_capture

        super
      end

      def before_teardown
        return if headless.nil?

        if failures.empty? || record_disabled?
          headless.video.stop_and_discard
        else
          video = video_dir.join("failures_#{self.name}.mp4")
          headless.video.stop_and_save(video)
          puts "[Video]: #{video}" if File.exist?(video)
        end
      ensure
        super
      end
    end
  end
end
