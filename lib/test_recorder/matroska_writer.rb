module TestRecorder
  # Writes a Matroska stream holding a single MJPEG video track, where every frame carries the
  # time it was captured. Chrome emits a screencast frame only when the page repaints, so frames
  # are not evenly spaced; keeping the real times lets ffmpeg reproduce the original pacing
  # instead of assuming a fixed frame rate.
  #
  # Written against the specifications:
  #   EBML     https://datatracker.ietf.org/doc/html/rfc8794
  #   Matroska https://datatracker.ietf.org/doc/html/rfc9559
  #   Codecs   https://datatracker.ietf.org/doc/html/draft-ietf-cellar-codec
  #
  # RFC 9559 updates RFC 8794, so read the two together: it makes 0x80 a legal EBML ID, which
  # leaves 0xFF as the only reserved one. Codec IDs such as V_MJPEG are defined by neither, but by
  # the codec document, which is still a draft.
  #
  # Only the elements those specifications require for this kind of stream are emitted. The stream
  # is written as it is captured, so the sizes of the Segment and of each Cluster are not known
  # when they start and are left unknown, which Matroska allows for those two elements alone.
  class MatroskaWriter
    # Element IDs, as defined by Matroska. The leading byte of an ID already encodes how many
    # bytes the ID occupies, so an ID is written as the minimal big endian form of these numbers.
    module Id
      EBML = 0x1A45DFA3
      EBML_VERSION = 0x4286
      EBML_READ_VERSION = 0x42F7
      EBML_MAX_ID_LENGTH = 0x42F2
      EBML_MAX_SIZE_LENGTH = 0x42F3
      DOC_TYPE = 0x4282
      DOC_TYPE_VERSION = 0x4287
      DOC_TYPE_READ_VERSION = 0x4285
      SEGMENT = 0x18538067
      INFO = 0x1549A966
      TIMESTAMP_SCALE = 0x2AD7B1
      MUXING_APP = 0x4D80
      WRITING_APP = 0x5741
      TRACKS = 0x1654AE6B
      TRACK_ENTRY = 0xAE
      TRACK_NUMBER = 0xD7
      TRACK_UID = 0x73C5
      TRACK_TYPE = 0x83
      FLAG_LACING = 0x9C
      CODEC_ID = 0x86
      VIDEO = 0xE0
      PIXEL_WIDTH = 0xB0
      PIXEL_HEIGHT = 0xBA
      CLUSTER = 0x1F43B675
      TIMESTAMP = 0xE7
      SIMPLE_BLOCK = 0xA3
    end
    private_constant :Id

    # A size whose data bits are all ones means "unknown". One byte is enough to say that.
    UNKNOWN_SIZE = [0xFF].pack("C")

    # TimestampScale is given in nanoseconds per tick, so this makes every timestamp in the stream
    # a number of milliseconds.
    TIMESTAMP_SCALE_NS = 1_000_000

    # A block states its time as a 16 bit signed offset from the timestamp of its cluster, so a
    # cluster can only cover about 32 seconds. Matroska also recommends keeping clusters short,
    # a few seconds at most.
    MAX_CLUSTER_DURATION_MS = 5_000

    TRACK_NUMBER = 1
    TRACK_TYPE_VIDEO = 1
    KEYFRAME = 0x80

    def initialize(io)
      @io = io
      @cluster_timestamp_ms = nil

      write_header
    end

    # Appends one JPEG, shown at the given number of milliseconds from the start of the stream.
    # Timestamps must not go backwards.
    def write_frame(frame, timestamp_ms)
      open_cluster(timestamp_ms) if start_new_cluster?(timestamp_ms)

      # The block header is written separately from the frame so that the frame, which is by far
      # the largest part, never has to be copied into another string.
      @io.write(simple_block_header(frame.bytesize, timestamp_ms - @cluster_timestamp_ms))
      @io.write(frame)
    end

    private

    def write_header
      @io.write(element(Id::EBML, [
        element(Id::EBML_VERSION, uint(1)),
        element(Id::EBML_READ_VERSION, uint(1)),
        element(Id::EBML_MAX_ID_LENGTH, uint(4)),
        element(Id::EBML_MAX_SIZE_LENGTH, uint(8)),
        element(Id::DOC_TYPE, "matroska"),
        element(Id::DOC_TYPE_VERSION, uint(4)),
        element(Id::DOC_TYPE_READ_VERSION, uint(2))
      ].join))

      # Everything below lives inside the segment, which stays open until the file ends.
      @io.write(id(Id::SEGMENT) + UNKNOWN_SIZE)

      @io.write(element(Id::INFO, [
        element(Id::TIMESTAMP_SCALE, uint(TIMESTAMP_SCALE_NS)),
        element(Id::MUXING_APP, "test-recorder"),
        element(Id::WRITING_APP, "test-recorder")
      ].join))

      @io.write(element(Id::TRACKS, element(Id::TRACK_ENTRY, [
        element(Id::TRACK_NUMBER, uint(TRACK_NUMBER)),
        element(Id::TRACK_UID, uint(TRACK_NUMBER)),
        element(Id::TRACK_TYPE, uint(TRACK_TYPE_VIDEO)),
        # Lacing packs several frames into one block. Each frame here is a whole picture with its
        # own time, so it is turned off.
        element(Id::FLAG_LACING, uint(0)),
        element(Id::CODEC_ID, "V_MJPEG"),
        # PixelWidth and PixelHeight are mandatory, but the frame size is not known before the
        # first frame arrives, and the browser may change it mid recording. Every JPEG states its
        # own size, so declare the smallest allowed picture and let the decoder use the real one.
        # Declaring a plausible size instead is actively harmful: ffmpeg then compares it with the
        # size it decodes and can read a shorter picture as one field of an interlaced frame.
        element(Id::VIDEO, element(Id::PIXEL_WIDTH, uint(1)) + element(Id::PIXEL_HEIGHT, uint(1)))
      ].join)))
    end

    def start_new_cluster?(timestamp_ms)
      @cluster_timestamp_ms.nil? || timestamp_ms - @cluster_timestamp_ms > MAX_CLUSTER_DURATION_MS
    end

    def open_cluster(timestamp_ms)
      @io.write(id(Id::CLUSTER) + UNKNOWN_SIZE)
      @io.write(element(Id::TIMESTAMP, uint(timestamp_ms)))
      @cluster_timestamp_ms = timestamp_ms
    end

    def simple_block_header(frame_length, relative_ms)
      track = vint(TRACK_NUMBER)
      # The payload is the track number, the 16 bit offset, the flags and then the frame itself.
      size = track.bytesize + 2 + 1 + frame_length

      id(Id::SIMPLE_BLOCK) + vint(size) + track + [relative_ms].pack("s>") + [KEYFRAME].pack("C")
    end

    # An element is its ID, then its length as a variable size integer, then its content.
    def element(element_id, content)
      id(element_id) + vint(content.bytesize) + content
    end

    # A variable size integer starts with a marker bit that says how many bytes it spans, and
    # carries the value in the bits after it. A value that would fill every remaining bit is
    # reserved to mean "unknown", so it needs one more byte.
    def vint(value)
      width = 1
      width += 1 until value < (1 << (7 * width)) - 1

      bytes = big_endian_bytes(value, width)
      bytes[0] |= 1 << (8 - width)
      bytes.pack("C*")
    end

    # Numbers are stored big endian, in as few bytes as they fit into.
    def uint(value)
      big_endian_bytes(value).pack("C*")
    end
    alias id uint

    def big_endian_bytes(value, width = nil)
      bytes = []
      loop do
        bytes.unshift(value & 0xFF)
        value >>= 8
        break if value.zero?
      end
      bytes.unshift(0) while width && bytes.size < width
      bytes
    end
  end
end
