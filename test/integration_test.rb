require "test_helper"
require "fileutils"

class TestRecorderTest < Minitest::Test
  def test_rails
    Bundler.with_unbundled_env do
      Dir.chdir("test/dummy") do
        quietly { system("bundle install", exception: true) }

        system("bin/rails t test/system/todos_test.rb")

        assert File.exist? "tmp/videos/failures_test_updating_a_Todo.webm"
        assert File.size("tmp/videos/failures_test_updating_a_Todo.webm").positive?
        assert File.exist? "tmp/videos/failures_test_updating_a_Todo_from__todos__id_edit.webm"
        assert File.size("tmp/videos/failures_test_updating_a_Todo_from__todos__id_edit.webm").positive?

        on_screen = 5 * 0.5
        video = "tmp/videos/failures_test_failing_after_the_page_has_been_shown_for_a_while.webm"
        assert File.exist? video
        duration = video_duration(video)
        assert_operator duration, :>=, on_screen - 0.1
        assert_operator duration, :<=, on_screen + 8.0

        refute File.exist? "tmp/videos/failures_test_skipping_after_the_page_is_loaded.webm"
        refute File.exist? "tmp/videos/failures_test_without_test_recorder.webm"
        refute File.exist? "tmp/videos/failures_test_failing_before_the_page_is_loaded.webm"
      end
    end
  ensure
    FileUtils.rm_rf("test/dummy/tmp/videos")
  end

  def test_rspec
    Bundler.with_unbundled_env do
      Dir.chdir("test/dummy") do
        quietly { system("bundle install", exception: true) }

        system("bin/rspec spec/system/todos_spec.rb")

        files = Dir.glob("tmp/videos/failures_creating_a_todo_*.webm")
        refute files.size.zero?
        assert File.size(files.first).positive?

        files = Dir.glob("tmp/videos/failures_with_aggregate_failures_*.webm")
        refute files.size.zero?
        assert File.size(files.first).positive?

        files = Dir.glob("tmp/videos/failures_with_retry_*.webm")
        refute files.size.zero?
        assert File.size(files.first).positive?

        files = Dir.glob("tmp/videos/failures_without_test_recorder_*.webm")
        assert files.size.zero?
      end
    end
  ensure
    FileUtils.rm_rf("test/dummy/tmp/videos")
  end


  def video_duration(path)
    output = IO.popen(["ffmpeg", "-i", path, "-f", "null", "-"], err: [:child, :out], &:read)
    timings = output.scan(/time=(\d+):(\d+):(\d+(?:\.\d+)?)/)
    refute_empty timings, "ffmpeg reported no duration for #{path}:\n#{output}"

    hours, minutes, seconds = timings.last
    hours.to_i * 3600 + minutes.to_i * 60 + seconds.to_f
  end

  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(IO::NULL)
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end

  def quietly
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end
end
