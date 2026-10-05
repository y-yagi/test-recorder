require "fileutils"
require "selenium-webdriver"

require "test_recorder/screen_recording"
require "test_recorder/screencast"

module TestRecorder
  class CdpRecorder
    class << self
      def screen_recording_supported?(browser)
        support.fetch(browser) { support[browser] = probe_screen_recording(browser) }
      end

      private

      # Stopping when nothing is being recorded tells whether the command exists without starting
      # anything: Chrome 153+ answers "No active screen recording", older versions do not know it.
      def probe_screen_recording(browser)
        browser.execute_cdp("Page.stopScreenRecording")
        true
      rescue Selenium::WebDriver::Error::UnknownCommandError
        false
      rescue Selenium::WebDriver::Error::WebDriverError
        true
      end

      def support
        @support ||= {}.compare_by_identity
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

      browser = page.driver.browser
      @recording = if self.class.screen_recording_supported?(browser)
        ScreenRecording.new(browser)
      else
        Screencast.new(browser)
      end
      @recording.start
    rescue => e
      warn "[TestRecorder] Failed to start the recording: #{e.class}: #{e.message}"
      @started = false
    end

    def stop_and_discard
      return unless @started

      @recording.stop_and_discard
    rescue => e
      warn "[TestRecorder] Failed to stop the recording: #{e.class}: #{e.message}"
    end

    # `name` is the file name without an extension, since the format depends on how it was recorded.
    # Returns the path of the video, or "" when nothing was saved.
    def stop_and_save(name)
      return "" unless @started

      video_dir = ::Rails.root.join("tmp", "videos")
      FileUtils.mkdir_p(video_dir)
      video_path = video_dir.join("#{name}#{@recording.extension}").to_s

      @recording.stop_and_save(video_path) ? video_path : ""
    rescue => e
      # The browser can be gone by now (a crash, a closed window). The test's own failure is what
      # matters, so this must not replace it with an error from here.
      warn "[TestRecorder] Failed to save the recording: #{e.class}: #{e.message}"
      ""
    end
  end
end
