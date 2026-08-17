require "json"
require "selenium-webdriver"

module TestRecorder
  # The CDP WebSocket connection the worker process opens for itself.
  #
  # Selenium's WebSocketConnection always waits for a command's reply, and that wait
  # polls rather than being woken by the reply (Selenium::WebDriver::Wait with
  # RESPONSE_WAIT_INTERVAL = 0.1). The first poll almost always runs before the reply
  # has been read off the socket, so every command costs about 100ms even though the
  # browser answered immediately.
  #
  # `Page.screencastFrameAck` has no reply worth reading, and Chrome only sends the
  # next frame once the previous one is acked, so paying 100ms per frame caps the
  # capture at roughly 10 fps. `send_oneway` writes the command and moves on.
  class CdpConnection < Selenium::WebDriver::WebSocketConnection
    # Every one-way command reuses this id. The browser still replies, and the
    # superclass files replies in a hash keyed by id which nothing ever reads for
    # these, so a fresh id per ack would grow that hash for the lifetime of the
    # worker. Reusing one id keeps it at a single entry that is overwritten.
    #
    # It has to fit in a signed 32-bit int: Chrome answers anything larger with
    # "Message must have integer 'id' property" and, since the ack never lands, stops
    # sending frames after the first one. The superclass numbers its own commands from
    # 1 upwards and will never climb this far.
    ONEWAY_ID = 2**30

    def initialize(url:)
      # Guards the socket against two frame callbacks acking at the same time.
      # Commands sent through the superclass are left alone: they only happen while
      # no frames are in flight, and they are unsynchronized in Selenium anyway.
      @oneway_mutex = Mutex.new
      super
    end

    # Sends a command without waiting for its reply.
    def send_oneway(**payload)
      data = JSON.generate(payload.merge(id: ONEWAY_ID))
      frame = WebSocket::Frame::Outgoing::Client.new(version: ws.version, data: data, type: "text")
      @oneway_mutex.synchronize { socket.write(frame.to_s) }
    end
  end
end
