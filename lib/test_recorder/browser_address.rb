module TestRecorder
  # Resolves a CDP address from a Selenium browser's capabilities, without
  # touching the network (that's left to the worker process). Results are
  # cached per browser instance.
  class BrowserAddress
    class << self
      def resolve(browser)
        addresses.fetch(browser) { addresses[browser] = extract(browser.capabilities) }
      end

      private

      def addresses
        @addresses ||= {}.compare_by_identity
      end

      def extract(capabilities)
        capabilities["se:cdp"] ||
          debugger_address(capabilities["goog:chromeOptions"]) ||
          debugger_address(capabilities["ms:edgeOptions"])
      rescue StandardError
        nil
      end

      def debugger_address(options)
        return unless options

        address = options["debuggerAddress"]
        "http://#{address}" if address
      end
    end
  end
end
