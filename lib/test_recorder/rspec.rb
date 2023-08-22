require "test_recorder/cdp_recorder"
require "test_recorder/rspec/example_wrapper"

module TestRecorder
  module RSpec
    CHARS_TO_TRANSLATE = ['/', '.', ':', ',', "'", '"', " "].freeze

    class << self
      attr_accessor :cdp_recorder

      def after_failed_example(example)
        if passed?(example)
          cdp_recorder.stop_and_discard
        else
          video_path = cdp_recorder.stop_and_save("failures_#{method_name(example)}.webm").to_s
          if File.exist?(video_path)
            example.metadata[:extra_failure_lines] = [example.metadata[:extra_failure_lines], "[Video]: #{video_path}"].flatten
          end
        end
      end

      def method_name(example)
        example.description.underscore.tr(CHARS_TO_TRANSLATE.join, "_")[0...200] + "_#{rand(1000)}"
      end

      def passed?(example)
        return false if example.exception
        return true unless defined?(::RSpec::Expectations::FailureAggregator)

        failure_notifier = ::RSpec::Support.failure_notifier
        return true unless failure_notifier.is_a?(::RSpec::Expectations::FailureAggregator)

        failure_notifier.failures.empty? && failure_notifier.other_errors.empty?
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
