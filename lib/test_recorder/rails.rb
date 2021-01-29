require "test_recorder/rails/setup_and_teardown"

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include TestRecorder::Base
  include TestRecorder::Rails::SetupAndTeardown
end
