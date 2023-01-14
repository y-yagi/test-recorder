require "fileutils"

module TestRecorder
  class CdpRecorder
    def initialize(enabled:)
      @enabled = enabled
      @tmpdir = nil
      setup
    end

    def setup
      @video_dir = ::Rails.root.join("tmp", "videos")
      FileUtils.mkdir_p(@video_dir)
    end

    def start(page:, enabled: nil)
      enabled = @enabled if enabled.nil?
      return unless enabled

      @tmpdir = Dir.mktmpdir("testrecorder")
      counter = 1

      @page = page
      @page.driver.browser.devtools.page.enable

      @page.driver.browser.devtools.page.on(:screencast_frame) do |event|
        decoded_data = Base64.decode64(event["data"])
        filename = "%010d.jpeg" %  counter
        IO.binwrite("#{File.join(@tmpdir, filename)}", decoded_data) rescue nil
        counter += 1
        @page.driver.browser.devtools.page.screencast_frame_ack(session_id: event["sessionId"])
      end

      @page.driver.browser.devtools.page.start_screencast(format: "jpeg", quality: 90)
    end

    def stop_and_discard
      unless @enabeld
        @page.driver.browser.devtools.page.stop_screencast
        FileUtils.rm_rf(@tmpdir)
      end
    end

    def stop_and_save(filename)
      @page.driver.browser.devtools.page.stop_screencast unless @enabled

      return "" if @tmpdir.nil? || @page.nil?

      video_path = File.join(@video_dir, filename)

      args = %W(-loglevel error -f image2 -avioflags direct -fpsprobesize 0
        -probesize 32 -analyzeduration 0 -c:v mjpeg -i #{File.join(@tmpdir, "%010d.jpeg")}
        -y -an -r 25 -qmin 0 -qmax 50 -crf 8 -deadline realtime -speed 8 -b:v 1M
        -threads 1 #{video_path})
      system("ffmpeg", *args, exception: true)
      video_path
    rescue => e
      $stderr.puts("[TestRecorder] ffmpeg failed: #{e.message}")
    ensure
      FileUtils.rm_rf(@tmpdir) unless @tmpdir.nil?
    end
  end
end
