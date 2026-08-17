require "base64"
require "tempfile"

require "test_recorder/encoder"
require "test_recorder/frame_clock"
require "test_recorder/frame_writer"

module TestRecorder
  module Recorders
    # Records via a CDP connection opened by Selenium in the test process itself.
    # This is the original implementation, kept as a fallback for when a
    # separate recording process can't be used.
    class InProcess
      Record = Struct.new(:page, :io, :clock)

      class << self
        def record(devtools)
          records[devtools] ||= begin
            page = devtools.page
            page.enable

            record = Record.new(page, nil, FrameClock.new)
            page.on(:screencast_frame) do |event|
              write_frame(record, event)
              record.page.screencast_frame_ack(session_id: event["sessionId"])
            end
            record
          end
        end

        private

        def write_frame(record, event)
          record.io&.write(Base64.decode64(event["data"]), record.clock.frame_time(event))
        rescue IOError
          # A frame can still arrive after the recording was stopped and the file was closed.
        rescue => e
          warn "[TestRecorder] Failed to write a screencast frame: #{e.class}: #{e.message}"
        end

        def records
          @records ||= {}.compare_by_identity
        end
      end

      def start(page:)
        @tmp_video = Tempfile.new(["testrecorder", ".mkv"])
        @tmp_video.binmode

        @record = self.class.record(page.driver.browser.devtools)
        @frame_writer = FrameWriter.new(@tmp_video)
        @record.io = @frame_writer

        @record.page.start_screencast(format: "jpeg", quality: TestRecorder.jpeg_quality, max_width: TestRecorder.max_dimension, max_height: TestRecorder.max_dimension, every_nth_frame: TestRecorder.every_nth_frame)
      end

      def stop_and_discard
        @record.io = nil
        @record.page.stop_screencast
        @tmp_video.close!
      end

      def stop_and_save(filename)
        @record.io = nil
        @record.page.stop_screencast
        @frame_writer.finish
        @tmp_video.flush

        unless Encoder.enough_frames?(@frame_writer.frame_count)
          warn "[TestRecorder] #{Encoder::NO_PAGE_UPDATES_MESSAGE}"
          return ""
        end

        video_path = ::Rails.root.join("tmp", "videos", filename).to_s
        result = Encoder.encode(source_path: @tmp_video.path, output_path: video_path, duration: @frame_writer.duration)

        if result.error
          warn "[TestRecorder] #{result.error}"
          return ""
        end

        result.path
      ensure
        @tmp_video.close!
      end
    end
  end
end
