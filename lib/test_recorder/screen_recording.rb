require "base64"

module TestRecorder
  # Records with `Page.startScreenRecording` (Chrome 153+). Chrome captures the page at a fixed
  # frame rate and encodes an MP4 itself, so nothing needs to be encoded on this side. The commands
  # are sent with `execute_cdp`, which does not need the selenium-devtools gem.
  class ScreenRecording
    EXTENSION = ".mp4".freeze

    # The size of one `IO.read`.
    READ_SIZE = 1 << 20

    # What a new Chrome session shows before the test visits anything ("data:," is what
    # chromedriver opens with).
    BLANK_URLS = ["data:,", "about:blank"].freeze

    def initialize(browser)
      @browser = browser
    end

    def extension
      EXTENSION
    end

    def start
      @stream = @browser.execute_cdp("Page.startScreenRecording", maxWidth: TestRecorder.max_dimension, maxHeight: TestRecorder.max_dimension, frameRate: TestRecorder.frame_rate)["stream"]
    end

    def stop_and_discard
      stop
    ensure
      close_stream
    end

    # Returns true when the video was written to `video_path`.
    def stop_and_save(video_path)
      # Chrome captures at a fixed frame rate whether or not anything is drawn, so a test that
      # fails before it visits a page would still leave behind a video of the blank page it
      # started on.
      if blank_page?
        stop
        warn "[TestRecorder] The test failed before any page was loaded, so no video was saved."
        return false
      end

      stop
      read_stream_into(video_path)

      if File.zero?(video_path)
        warn "[TestRecorder] The screen recording was empty, so no video was saved."
        File.delete(video_path)
        return false
      end

      true
    rescue
      File.delete(video_path) if File.exist?(video_path)
      raise
    ensure
      close_stream
    end

    private

    def blank_page?
      BLANK_URLS.include?(@browser.current_url)
    rescue
      false
    end

    # The stream stays readable after this, so it has to be closed even if nobody reads it.
    def stop
      @browser.execute_cdp("Page.stopScreenRecording")
    end

    def read_stream_into(video_path)
      File.open(video_path, "wb") do |file|
        loop do
          chunk = @browser.execute_cdp("IO.read", handle: @stream, size: READ_SIZE)
          file.write(chunk["base64Encoded"] ? Base64.decode64(chunk["data"]) : chunk["data"])
          break if chunk["eof"]
        end
      end
    end

    # Runs on the way out of a failed stop or read too, so its own error must not hide that one.
    def close_stream
      @browser.execute_cdp("IO.close", handle: @stream)
    rescue => e
      warn "[TestRecorder] Failed to close the screen recording stream: #{e.class}: #{e.message}"
    end
  end
end
