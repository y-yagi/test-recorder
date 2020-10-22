require "videotest/recorder/minitest/setup_and_teardown"

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include Videotest::Recorder::Minitest::SetupAndTeardown
end
