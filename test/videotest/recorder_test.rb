require "test_helper"

class Videotest::RecorderTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Videotest::Recorder::VERSION
  end
end
