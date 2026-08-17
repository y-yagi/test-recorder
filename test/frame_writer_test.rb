require "test_helper"
require "stringio"
require "test_recorder/frame_writer"

class FrameWriterTest < Minitest::Test
  FIRST_FRAME_TIME = 1_700_000_000.0

  def test_the_video_is_as_long_as_the_gap_between_the_first_and_the_last_frame
    writer = build_writer
    writer.write("a", FIRST_FRAME_TIME)
    writer.write("b", FIRST_FRAME_TIME + 2.5)
    writer.finish

    assert_equal 2, writer.frame_count
    assert_in_delta 2.5 + TestRecorder::FrameWriter::MIN_LAST_FRAME_DURATION, writer.duration, 0.001
  end

  def test_the_video_covers_the_time_between_the_last_repaint_and_the_end_of_the_test
    writer = build_writer(clock: [0.0, 0.0, 3.0])
    writer.write("a", FIRST_FRAME_TIME)
    writer.write("b", FIRST_FRAME_TIME + 0.5)
    writer.finish

    assert_in_delta 0.5 + 3.0, writer.duration, 0.001
  end

  def test_the_last_frame_stays_on_screen_even_when_the_test_ends_right_after_it
    writer = build_writer
    writer.write("a", FIRST_FRAME_TIME)
    writer.finish

    assert_in_delta TestRecorder::FrameWriter::MIN_LAST_FRAME_DURATION, writer.duration, 0.001
  end

  def test_a_long_wait_before_the_test_fails_does_not_stretch_the_video_without_bound
    writer = build_writer(clock: [0.0, 0.0, 60.0])
    writer.write("a", FIRST_FRAME_TIME)
    writer.write("b", FIRST_FRAME_TIME + 0.5)
    writer.finish

    assert_in_delta 0.5 + TestRecorder::FrameWriter::MAX_LAST_FRAME_DURATION, writer.duration, 0.001
  end

  def test_a_timestamp_that_goes_backwards_does_not_shorten_the_video
    writer = build_writer
    writer.write("a", FIRST_FRAME_TIME)
    writer.write("b", FIRST_FRAME_TIME + 2.0)
    writer.write("c", FIRST_FRAME_TIME + 1.0)
    writer.finish

    assert_in_delta 2.0 + TestRecorder::FrameWriter::MIN_LAST_FRAME_DURATION, writer.duration, 0.001
  end

  def test_there_is_no_duration_when_no_frame_was_captured
    writer = build_writer
    writer.finish

    assert writer.empty?
    assert_equal 0, writer.frame_count
    assert_nil writer.duration
  end

  def test_finishing_twice_neither_lengthens_the_video_nor_writes_to_the_closed_file
    io = StringIO.new
    writer = build_writer(io)
    writer.write("a", FIRST_FRAME_TIME)
    writer.finish

    duration = writer.duration
    frame_count = writer.frame_count
    io.close

    writer.finish

    assert_equal duration, writer.duration
    assert_equal frame_count, writer.frame_count
  end

  private

  def build_writer(io = StringIO.new, clock: [0.0])
    writer = TestRecorder::FrameWriter.new(io)
    readings = clock.dup
    writer.define_singleton_method(:monotonic_time) { readings.size > 1 ? readings.shift : readings.first }
    writer
  end
end
