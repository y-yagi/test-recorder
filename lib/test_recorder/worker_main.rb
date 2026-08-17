require "selenium-webdriver"
require "json"
require "base64"
require "fileutils"
require "tempfile"
require "net/http"

module TestRecorder
  # Runs in its own process, spawned by Recorders::Worker. Speaks a small
  # newline-delimited JSON protocol over stdin/stdout, and holds its own CDP
  # connection to Chrome so frame handling never touches the test process.
  class WorkerMain
    # Raised when Chrome answers a CDP command with an "error" payload.
    class CdpError < StandardError; end

    FFMPEG_ENCODE_OPTIONS = %w[-y -an -r 25 -qmin 0 -qmax 50 -crf 8 -deadline realtime -speed 8 -b:v 1M -threads 1].freeze

    def initialize
      @ws = nil
      @ws_url = nil
      @session_id = nil
      @callback_registered = false
      @io = nil
      @tmp_video = nil
      @pending_error = nil
      @every_nth_frame = 1
      @cdp_mutex = Mutex.new
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

      @tmp_video = Tempfile.new(["testrecorder", ".mjpeg"])
      @tmp_video.binmode
      @io = @tmp_video
      @every_nth_frame = request["every_nth_frame"] || 1
      @pending_error = nil

      cdp_send("Page.startScreencast", {format: "jpeg", quality: request["quality"],
                                        maxWidth: request["max_dimension"], maxHeight: request["max_dimension"],
                                        everyNthFrame: @every_nth_frame})
      respond(ok: true)
    rescue StandardError => e
      @io = nil
      @tmp_video&.close!
      @tmp_video = nil
      message = "#{e.class}: #{e.message}"
      warn "test-recorder worker: #{message}"
      respond(ok: false, error: message)
    end

    def discard_recording
      @io = nil
      cdp_send("Page.stopScreencast", {})
    rescue StandardError => e
      warn "test-recorder worker: #{e.class}: #{e.message}"
    ensure
      @tmp_video&.close!
      @tmp_video = nil
    end

    def save_recording(path)
      @io = nil

      # A stopScreencast failure shouldn't discard whatever frames were already
      # captured: note it and keep going, so a still-valid video is still encoded.
      begin
        cdp_send("Page.stopScreencast", {})
      rescue StandardError => e
        note_pending_error(e)
      end

      @tmp_video.flush

      FileUtils.mkdir_p(File.dirname(path))
      # Chrome captures at about 25 fps, but `every_nth_frame` makes it deliver only
      # one out of every N frames. So the captured file holds 25 / N frames per second.
      # Tell ffmpeg that input rate, otherwise it assumes 25 fps and the video plays
      # N times faster than the actual test.
      ok = system("ffmpeg", "-loglevel", "quiet", "-f", "image2pipe", "-c:v", "mjpeg", "-framerate", "25/#{@every_nth_frame}", "-i", @tmp_video.path, *FFMPEG_ENCODE_OPTIONS, path)

      # @pending_error (e.g. a stray frame ack failure) is not by itself fatal: the
      # video can still be valid. Only surface it as a hard error if the output
      # wasn't actually produced, where it's a useful diagnostic hint.
      error = nil
      unless ok && File.exist?(path) && File.size(path).positive?
        reason = "ffmpeg failed to produce #{path}"
        reason += " (no screencast frames were captured)" if File.size(@tmp_video.path).zero?
        reason += " (#{@pending_error})" if @pending_error
        error = reason
      end

      @tmp_video.close!
      @tmp_video = nil
      @pending_error = nil

      response = {ok: error.nil?, path: path}
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
      @ws = Selenium::WebDriver::WebSocketConnection.new(url: ws_url)
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
      @io&.write(Base64.decode64(params["data"])) rescue nil
      cdp_send("Page.screencastFrameAck", {sessionId: params["sessionId"]})
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
