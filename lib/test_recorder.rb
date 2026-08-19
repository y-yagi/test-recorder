require "test_recorder/version"

module TestRecorder
  DEFAULT_JPEG_QUALITY = 60
  DEFAULT_MAX_DIMENSION = 1000
  DEFAULT_EVERY_NTH_FRAME = 1

  CHARS_TO_TRANSLATE = ['/', '.', ':', ',', "'", '"', " "].freeze

  class << self
    attr_writer :jpeg_quality, :max_dimension, :every_nth_frame

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

    def every_nth_frame
      defined?(@every_nth_frame) ? @every_nth_frame : DEFAULT_EVERY_NTH_FRAME
    end

    def sanitize_filename(name)
      name.tr(CHARS_TO_TRANSLATE.join, "_")
    end
  end
end
