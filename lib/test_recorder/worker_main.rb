require "selenium-webdriver"
require "json"
require "base64"
require "tempfile"
require "net/http"

require "test_recorder/cdp_connection"
require "test_recorder/encoder"
require "test_recorder/frame_clock"
require "test_recorder/frame_writer"

module TestRecorder
  # Runs in its own process, spawned by Recorders::Worker. Speaks a small
  # newline-delimited JSON protocol over stdin/stdout, and holds its own CDP
  # connection to Chrome so frame handling never touches the test process.
  class WorkerMain
    # Raised when Chrome answers a CDP command with an "error" payload.
    class CdpError < StandardError; end

    def initialize
      @ws = nil
      @ws_url = nil
      @session_id = nil
      @callback_registered = false
      @io = nil
      @tmp_video = nil
      @pending_error = nil
      @clock = FrameClock.new
      @cdp_mutex = Mutex.new
      # Chrome dispatches every screencast frame on its own thread, so writes to the
      # capture file and `start`/`save`/`discard` swapping @io have to be serialized
      # against each other.
      @frame_mutex = Mutex.new
    end

    def run
      respond(ready: true)

      while (line = $stdin.gets)
        handle(line)
      end
    ensure
      @ws&.close
    end

    private

    def handle(line)
      request = JSON.parse(line)

      case request["cmd"]
      when "start"
        start_recording(request)
      when "discard"
        discard_recording
      when "save"
        save_recording(request["path"])
      when "shutdown"
        respond(ok: true)
        exit(0)
      end
    rescue StandardError => e
      @pending_error = "#{e.class}: #{e.message}"
      warn "test-recorder worker: #{@pending_error}"
    end

    def start_recording(request)
      connect(request["address"])

      @tmp_video = Tempfile.new(["testrecorder", ".mkv"])
      @tmp_video.binmode
      @frame_writer = FrameWriter.new(@tmp_video)
      @frame_mutex.synchronize { @io = @frame_writer }
      @pending_error = nil

      cdp_send("Page.startScreencast", {format: "jpeg", quality: request["quality"],
                                        maxWidth: request["max_dimension"], maxHeight: request["max_dimension"],
                                        everyNthFrame: request["every_nth_frame"] || 1})
      respond(ok: true)
    rescue StandardError => e
      @frame_mutex.synchronize { @io = nil }
      @tmp_video&.close!
      @tmp_video = nil
      message = "#{e.class}: #{e.message}"
      warn "test-recorder worker: #{message}"
      respond(ok: false, error: message)
    end

    def discard_recording
      @frame_mutex.synchronize { @io = nil }
      cdp_send("Page.stopScreencast", {})
    rescue StandardError => e
      warn "test-recorder worker: #{e.class}: #{e.message}"
    ensure
      @tmp_video&.close!
      @tmp_video = nil
    end

    def save_recording(path)
      @frame_mutex.synchronize { @io = nil }

      # A stopScreencast failure shouldn't discard whatever frames were already
      # captured: note it and keep going, so a still-valid video is still encoded.
      begin
        cdp_send("Page.stopScreencast", {})
      rescue StandardError => e
        note_pending_error(e)
      end

      @frame_writer.finish
      @tmp_video.flush

      # Chrome sends a frame as soon as the screencast starts, so a test that fails
      # before it draws anything still leaves behind the one frame of the blank page
      # it started on. Report success with no path so the test process knows there is
      # nothing to show, rather than saving a one-frame video.
      unless Encoder.enough_frames?(@frame_writer.frame_count)
        warn "[TestRecorder] #{Encoder::NO_PAGE_UPDATES_MESSAGE}"
        @tmp_video.close!
        @tmp_video = nil
        @pending_error = nil
        respond(ok: true, path: "")
        return
      end

      result = Encoder.encode(source_path: @tmp_video.path, output_path: path, duration: @frame_writer.duration)

      # @pending_error (e.g. a stray frame ack failure) is not by itself fatal: the
      # video can still be valid. Only surface it as a hard error if the output
      # wasn't actually produced, where it's a useful diagnostic hint.
      error = result.error
      error += " (#{@pending_error})" if error && @pending_error

      @tmp_video.close!
      @tmp_video = nil
      @pending_error = nil

      response = {ok: error.nil?, path: result.path || ""}
      response[:error] = error if error
      respond(response)
    rescue StandardError => e
      @tmp_video&.close! rescue nil
      @tmp_video = nil
      @pending_error = nil
      message = "#{e.class}: #{e.message}"
      warn "test-recorder worker: #{message}"
      respond(ok: false, error: message)
    end

    def connect(address)
      ws_url = resolve_ws_url(address)
      return if ws_url == @ws_url && @ws

      @ws&.close
      @ws = CdpConnection.new(url: ws_url)
      @ws_url = ws_url
      @callback_registered = false
      attach
    end

    def resolve_ws_url(address)
      return address if address.start_with?("ws://", "wss://")

      uri = URI("#{address}/json/version")
      response = Net::HTTP.get(uri.hostname, uri.request_uri, uri.port)
      JSON.parse(response)["webSocketDebuggerUrl"]
    end

    def attach
      targets = raw_cdp_send(method: "Target.getTargets", params: {})
      page_target = targets.dig("result", "targetInfos")&.find { |target| target["type"] == "page" }
      raise "no page target found" unless page_target

      attached = raw_cdp_send(method: "Target.attachToTarget", params: {targetId: page_target["targetId"], flatten: true})
      @session_id = attached.dig("result", "sessionId")
      raise "failed to attach to target" unless @session_id

      # Called with retried: true because otherwise a session error here would make
      # cdp_send call back into attach, which could recurse without bound.
      cdp_send("Page.enable", {}, retried: true)

      return if @callback_registered

      @ws.add_callback("Page.screencastFrame") { |params| on_screencast_frame(params) }
      @callback_registered = true
    end

    def on_screencast_frame(params)
      frame = Base64.decode64(params["data"])
      time = @clock.frame_time(params)

      @frame_mutex.synchronize { @io&.write(frame, time) }

      # Ack after the frame has been written, never before: Chrome holds off the next
      # frame until the current one is acked, and that is the only thing keeping the
      # worker from falling behind the browser.
      #
      # This deliberately does not go through cdp_send. Waiting for the ack's reply
      # costs about 100ms (see CdpConnection), and since Chrome waits for the ack
      # before sending again, that wait alone would cap the capture near 10 fps.
      @ws.send_oneway(method: "Page.screencastFrameAck",
                      params: {sessionId: params["sessionId"]},
                      sessionId: @session_id)
    rescue StandardError => e
      note_pending_error(e)
    end

    def note_pending_error(e)
      message = "#{e.class}: #{e.message}"
      @pending_error ||= message
      warn "test-recorder worker: #{message}"
    end

    def cdp_send(method, params, retried: false)
      message = raw_cdp_send(method: method, params: params, sessionId: @session_id)

      if message["error"]
        if !retried && session_error?(message["error"])
          attach
          return cdp_send(method, params, retried: true)
        end

        raise CdpError, message["error"]["message"].to_s
      end

      message
    end

    def raw_cdp_send(payload)
      @cdp_mutex.synchronize { @ws.send_cmd(**payload) }
    end

    def session_error?(error)
      message = error["message"].to_s.downcase
      message.include?("session") || message.include?("no target with given id")
    end

    def respond(payload)
      puts JSON.generate(payload)
      $stdout.flush
    end
  end
end

$stdout.sync = true
TestRecorder::WorkerMain.new.run
