require "json"
require "rbconfig"
require "test_recorder/browser_address"

module TestRecorder
  module Recorders
    # Client for the separate recording process. Spawns lib/test_recorder/worker_main.rb
    # and talks to it over a newline-delimited JSON protocol on its stdin/stdout.
    class Worker
      class Error < StandardError; end

      READY_TIMEOUT = 10
      SAVE_TIMEOUT = 60
      WORKER_MAIN = File.expand_path("../worker_main.rb", __dir__)

      def initialize
        @io = nil
        @owner_pid = nil
      end

      def start(page:)
        ensure_worker

        address = BrowserAddress.resolve(page.driver.browser)
        raise Error, "could not resolve a CDP address for the browser" unless address

        write(cmd: "start", address: address, quality: TestRecorder.jpeg_quality, max_dimension: TestRecorder.max_dimension, every_nth_frame: TestRecorder.every_nth_frame)
      end

      def stop_and_discard
        write(cmd: "discard")
      end

      def stop_and_save(filename)
        path = ::Rails.root.join("tmp", "videos", filename).to_s

        write(cmd: "save", path: path)
        response = read(timeout: SAVE_TIMEOUT)
        raise Error, "worker process did not respond to save" unless response

        response["path"] || path
      end

      private

      def ensure_worker
        @io = nil if @io && @owner_pid != Process.pid
        spawn_worker if @io.nil?
      end

      def spawn_worker
        env = {"RUBYLIB" => $LOAD_PATH.join(File::PATH_SEPARATOR)}
        @io = IO.popen(env, [RbConfig.ruby, WORKER_MAIN], "r+")
        @io.sync = true
        @owner_pid = Process.pid

        ready = read(timeout: READY_TIMEOUT)
        raise Error, "worker process did not become ready" unless ready && ready["ready"]

        at_exit { shutdown }
      end

      def shutdown
        return unless @io && @owner_pid == Process.pid

        begin
          write(cmd: "shutdown")
          read(timeout: READY_TIMEOUT)
        rescue StandardError
        end

        begin
          Process.waitpid(@io.pid)
        rescue Errno::ECHILD
        end

        @io.close rescue nil
        @io = nil
      end

      def write(payload)
        @io.puts(JSON.generate(payload))
      rescue Errno::EPIPE, IOError => e
        raise Error, "worker process is not available (#{e.class}: #{e.message})"
      end

      def read(timeout:)
        raise Error, "worker process is not available" unless IO.select([@io], nil, nil, timeout)

        line = @io.gets
        return nil unless line

        JSON.parse(line)
      rescue Errno::EPIPE, IOError => e
        raise Error, "worker process is not available (#{e.class}: #{e.message})"
      end
    end
  end
end
