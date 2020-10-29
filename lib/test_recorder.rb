require "test_recorder/version"

module TestRecorder
  module Base
    def enable_record!
      @record_disabled = false
    end

    def disable_record!
      @record_disabled = true
    end

    def record_disabled?
      return false unless defined?(@record_disabled)
      @record_disabled
    end
  end
end
