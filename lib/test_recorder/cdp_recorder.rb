require "open3"
require "fileutils"
require "tempfile"

module TestRecorder
  class CdpRecorder
    def initialize(enabled:)
      @enabled = enabled
      @page = nil
      setup
    end

    def setup
      @video_dir = ::Rails.root.join("tmp", "videos")
      FileUtils.mkdir_p(@video_dir)
    end

    def start(page:, enabled: nil)
      enabled = @enabled if enabled.nil?
      return unless enabled

      @tmp_video = Tempfile.open(["testrecorder", ".webm"])
      cmd = "ffmpeg -loglevel quiet -f image2pipe -avioflags direct -fpsprobesize 0 -probesize 32 -analyzeduration 0 -c:v mjpeg -i - -y -an -r 25 -qmin 0 -qmax 50 -crf 8 -deadline realtime -speed 8 -b:v 1M -threads 1 #{@tmp_video.path}"
      @stdin, @wait_thrs = *Open3.pipeline_w(cmd)
      @stdin.set_encoding("ASCII-8BIT")

      @page = page
      @page.driver.browser.devtools.page.enable

      @page.driver.browser.devtools.page.on(:screencast_frame) do |event|
        decoded_data = Base64.decode64(event["data"])
        @stdin.print(decoded_data) rescue nil
        @page.driver.browser.devtools.page.screencast_frame_ack(session_id: event["sessionId"])
      end

      @page.driver.browser.devtools.page.start_screencast(format: "jpeg", quality: 90)
    end

    def stop_and_discard
      unless @page.nil?
        @page.driver.browser.devtools.page.stop_screencast
        @stdin.close
      end
    end

    def stop_and_save(filename)
      return "" if @page.nil?

      @page.driver.browser.devtools.page.stop_screencast
      @stdin.close
      @wait_thrs.each(&:join)

      video_path = File.join(@video_dir, filename)
      FileUtils.copy(@tmp_video.path, video_path)
      @tmp_video.close(true)

      video_path
    end
  end
end
