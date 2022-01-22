require "test_recorder/version"

module TestRecorder
  class << self
    def enable!
      @enable = true
    end

    def disable!
      @enable = false
    end

    def enabled?
      defined?(@enable) ? @enable : true
    end
  end
end
