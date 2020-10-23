require "headless"

module Videotest
  module Recorder
    module Rails
      module SetupAndTeardown
        attr_reader :video_dir, :headless

        def before_setup
          @video_dir = ::Rails.root.join("tmp", "videos")
          FileUtils.mkdir(video_dir) unless Dir.exist?(video_dir)

          # TODO: Allow configuring parameters.
          @headless = Headless.new(video: { provider: :ffmpeg, codec: :libx264, extra: %w(-preset ultrafast) })
          headless.start
          headless.video.start_capture

          super
        end

        def before_teardown
          if failures.empty?
            headless.video.stop_and_discard
          else
            video = video_dir.join("failures_#{self.name}.mp4")
            headless.video.stop_and_save(video)
            puts "[Video]: #{video}"
          end
        ensure
          super
        end
      end
    end
  end
end
