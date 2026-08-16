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

      cdp_send("Page.startScreencast", format: "jpeg", quality: request["quality"],
                                        maxWidth: request["max_dimension"], maxHeight: request["max_dimension"],
                                        everyNthFrame: @every_nth_frame)
    end

    def discard_recording
      @io = nil
      cdp_send("Page.stopScreencast", {})
      @tmp_video&.close!
      @tmp_video = nil
    end

    def save_recording(path)
      @io = nil
      cdp_send("Page.stopScreencast", {})
      @tmp_video.flush

      FileUtils.mkdir_p(File.dirname(path))
      # Chrome captures at about 25 fps, but `every_nth_frame` makes it deliver only
      # one out of every N frames. So the captured file holds 25 / N frames per second.
      # Tell ffmpeg that input rate, otherwise it assumes 25 fps and the video plays
      # N times faster than the actual test.
      system("ffmpeg", "-loglevel", "quiet", "-f", "image2pipe", "-c:v", "mjpeg", "-framerate", "25/#{@every_nth_frame}", "-i", @tmp_video.path, *FFMPEG_ENCODE_OPTIONS, path)

      @tmp_video.close!
      @tmp_video = nil

      response = {ok: true, path: path}
      response[:error] = @pending_error if @pending_error
      @pending_error = nil
      respond(response)
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

      cdp_send("Page.enable", {})

      return if @callback_registered

      @ws.add_callback("Page.screencastFrame") { |params| on_screencast_frame(params) }
      @callback_registered = true
    end

    def on_screencast_frame(params)
      @io&.write(Base64.decode64(params["data"])) rescue nil
      cdp_send("Page.screencastFrameAck", sessionId: params["sessionId"])
    end

    def cdp_send(method, params)
      message = raw_cdp_send(method: method, params: params, sessionId: @session_id)
      attach if message["error"] && session_error?(message["error"])
      message
    end

    def raw_cdp_send(payload)
      @ws.send_cmd(**payload)
    end

    def session_error?(error)
      error["message"].to_s.include?("session")
    end

    def respond(payload)
      puts JSON.generate(payload)
      $stdout.flush
    end
  end
end

$stdout.sync = true
TestRecorder::WorkerMain.new.run
