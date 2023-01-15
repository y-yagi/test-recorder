require "test_helper"
require "fileutils"

class TestRecorderTest < Minitest::Test
  def test_rails
    Bundler.with_unbundled_env do
      Dir.chdir("test/dummy") do
        quietly { system("bundle install", exception: true) }

        system("bin/rails t test/system/todos_test.rb")

        assert File.exist? "tmp/videos/failures_test_updating_a_Todo.webm"
        refute File.exist? "tmp/videos/failures_test_without_test_recorder.webm"
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

        files = Dir.glob("tmp/videos/failures_with_retry_*.webm")
        refute files.size.zero?

        files = Dir.glob("tmp/videos/failures_without_test_recorder_*.webm")
        assert files.size.zero?
      end
    end
  ensure
    FileUtils.rm_rf("test/dummy/tmp/videos")
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
