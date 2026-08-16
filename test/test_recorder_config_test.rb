require "test_helper"
require "test_recorder"

class TestRecorderConfigTest < Minitest::Test
  def teardown
    reset_ivar(:@jpeg_quality)
    reset_ivar(:@max_dimension)
    reset_ivar(:@every_nth_frame)
    reset_ivar(:@separate_process)
  end

  def test_default_jpeg_quality
    assert_equal TestRecorder::DEFAULT_JPEG_QUALITY, TestRecorder.jpeg_quality
  end

  def test_default_max_dimension
    assert_equal TestRecorder::DEFAULT_MAX_DIMENSION, TestRecorder.max_dimension
  end

  def test_jpeg_quality_is_configurable
    TestRecorder.jpeg_quality = 80
    assert_equal 80, TestRecorder.jpeg_quality
  end

  def test_max_dimension_is_configurable
    TestRecorder.max_dimension = 1280
    assert_equal 1280, TestRecorder.max_dimension
  end

  def test_default_every_nth_frame
    assert_equal TestRecorder::DEFAULT_EVERY_NTH_FRAME, TestRecorder.every_nth_frame
  end

  def test_every_nth_frame_is_configurable
    TestRecorder.every_nth_frame = 3
    assert_equal 3, TestRecorder.every_nth_frame
  end

  def test_default_separate_process
    assert_equal TestRecorder::DEFAULT_SEPARATE_PROCESS, TestRecorder.separate_process
  end

  def test_separate_process_is_configurable
    TestRecorder.separate_process = true
    assert_equal true, TestRecorder.separate_process
  end

  private

  def reset_ivar(name)
    TestRecorder.remove_instance_variable(name) if TestRecorder.instance_variable_defined?(name)
  end
end
