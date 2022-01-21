module TestRecorder
  module RSpec
    module ExampleWrapper
      def run_before_example
        super
        TestRecorder::RSpec.cdp_recorder.start(
          page: @example_group_instance.page,
          enabled: self.metadata[:test_recorder]
        )
      end
    end
  end
end
