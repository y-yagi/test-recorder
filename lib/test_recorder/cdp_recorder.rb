require "base64"
require "fileutils"
require "tempfile"

module TestRecorder
  class CdpRecorder
    FFMPEG_ENCODE_OPTIONS = %w[-y -an -r 25 -c:v vp8 -qmin 0 -qmax 50 -crf 8 -deadline realtime -speed 8 -b:v 1M -threads 1].freeze

    Record = Struct.new(:page, :io)

    class << self
      def record(devtools)
        records[devtools] ||= begin
          page = devtools.page
          page.enable

          record = Record.new(page, nil)
          page.on(:screencast_frame) do |event|
            record.io&.write(Base64.decode64(event["data"])) rescue nil
            record.page.screencast_frame_ack(session_id: event["sessionId"])
          end
          record
        end
      end

      private

      def records
        @records ||= {}.compare_by_identity
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

      @tmp_video = Tempfile.new(["testrecorder", ".mjpeg"])
      @tmp_video.binmode

      @record = self.class.record(page.driver.browser.devtools)
      @record.io = @tmp_video

      @every_nth_frame = TestRecorder.every_nth_frame

      @record.page.start_screencast(format: "jpeg", quality: TestRecorder.jpeg_quality, max_width: TestRecorder.max_dimension, max_height: TestRecorder.max_dimension, every_nth_frame: @every_nth_frame)
    end

    def stop_and_discard
      return unless @started

      @record.io = nil
      @record.page.stop_screencast
      @tmp_video.close!
    end

    def stop_and_save(filename)
      return "" unless @started

      @record.io = nil
      @record.page.stop_screencast
      @tmp_video.flush

      video_dir = ::Rails.root.join("tmp", "videos")
      FileUtils.mkdir_p(video_dir)
      video_path = video_dir.join(filename).to_s

      # Chrome captures at about 25 fps, but `every_nth_frame` makes it deliver only
      # one out of every N frames. So the captured file holds 25 / N frames per second.
      # Tell ffmpeg that input rate, otherwise it assumes 25 fps and the video plays
      # N times faster than the actual test.
      system("ffmpeg", "-loglevel", "quiet", "-f", "image2pipe", "-c:v", "mjpeg", "-framerate", "25/#{@every_nth_frame}", "-i", @tmp_video.path, *FFMPEG_ENCODE_OPTIONS, video_path)

      @tmp_video.close!

      video_path
    end
  end
end
