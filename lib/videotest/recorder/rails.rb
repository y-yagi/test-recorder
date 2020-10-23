require "videotest/recorder/rails/setup_and_teardown"

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include Videotest::Recorder::Rails::SetupAndTeardown
end
