require "test_recorder/cdp_recorder"
require "test_recorder/rspec/example_wrapper"

module TestRecorder
  module RSpec
    CHARS_TO_TRANSLATE = ['/', '.', ':', ',', "'", '"', " "].freeze

    class << self
      attr_accessor :cdp_recorder

      def after_failed_example(example)
        if example.exception
          video_path = cdp_recorder.stop_and_save("failures_#{method_name(example)}.mp4").to_s
          if File.exist?(video_path)
            example.metadata[:extra_failure_lines] = [example.metadata[:extra_failure_lines], "[Video]: #{video_path}"].flatten
          end
        else
          cdp_recorder.stop_and_discard
        end
      end

      def method_name(example)
        example.description.underscore.tr(CHARS_TO_TRANSLATE.join, "_")[0...200] + "_#{rand(1000)}"
      end
    end
  end
end

RSpec::Core::Example.prepend(TestRecorder::RSpec::ExampleWrapper)

RSpec.configure do |config|
  TestRecorder::RSpec.cdp_recorder = TestRecorder::CdpRecorder.new(enabled: TestRecorder.enabled?)

  config.after(type: :system) do |example|
    TestRecorder::RSpec.after_failed_example(example)
  end

  config.after(type: :feature) do |example|
    TestRecorder::RSpec.after_failed_example(example)
  end
end
