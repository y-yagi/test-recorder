require "test_recorder/version"

module TestRecorder
  DEFAULT_JPEG_QUALITY = 60
  DEFAULT_MAX_DIMENSION = 1000

  class << self
    attr_writer :jpeg_quality, :max_dimension

    def enable!
      @enable = true
    end

    def disable!
      @enable = false
    end

    def enabled?
      defined?(@enable) ? @enable : true
    end

    def jpeg_quality
      defined?(@jpeg_quality) ? @jpeg_quality : DEFAULT_JPEG_QUALITY
    end

    def max_dimension
      defined?(@max_dimension) ? @max_dimension : DEFAULT_MAX_DIMENSION
    end
  end
end
