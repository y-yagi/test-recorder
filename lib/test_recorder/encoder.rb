require "fileutils"

module TestRecorder
  # Turns a captured Matroska stream into the final video.
  #
  # Both the in-process recorder and the worker process encode their own recording,
  # and when each carried its own copy of this they drifted: the worker's copy lost
  # the explicit VP8 codec and the "don't save an empty recording" rule. Keeping the
  # options and the ffmpeg call here means there is only one of each.
  module Encoder
    FFMPEG_ENCODE_OPTIONS = %w[-y -an -r 25 -c:v vp8 -qmin 0 -qmax 50 -crf 8 -deadline realtime -speed 8 -b:v 1M -threads 1].freeze

    # ffmpeg's -t treats the given duration as an exclusive cutoff, dropping the very frame that
    # marks the video's real length if it lands exactly on it. This nudges -t just past that frame
    # so it is kept, without adding a duration long enough to be noticeable.
    FFMPEG_DURATION_SLACK_S = 0.01

    # Chrome sends a frame as soon as the screencast starts, so a test that fails
    # before it draws anything still leaves behind the one frame of the blank page
    # it started on. A recording that short is not worth a video.
    MINIMUM_FRAMES = 2

    NO_PAGE_UPDATES_MESSAGE = "The screencast captured no page updates, so no video was saved."

    Result = Struct.new(:path, :error)

    class << self
      def enough_frames?(frame_count)
        frame_count >= MINIMUM_FRAMES
      end

      # Encodes the Matroska stream at source_path, which runs for `duration` seconds, into
      # output_path. Returns a Result whose `error` is nil on success, and whose `path` is nil when
      # the video could not be produced.
      def encode(source_path:, output_path:, duration:)
        FileUtils.mkdir_p(File.dirname(output_path))

        # Each frame carries its own timestamp in the Matroska stream, so ffmpeg knows how long to
        # hold it and duplicates frames to reach the constant output frame rate on its own. Without a
        # known end, though, ffmpeg pads however long it likes past the last real timestamp, so -t
        # caps the output at the video's real duration explicitly.
        result = system("ffmpeg", "-loglevel", "error", "-f", "matroska", "-i", source_path,
                        "-t", (duration + FFMPEG_DURATION_SLACK_S).to_s,
                        *FFMPEG_ENCODE_OPTIONS, output_path)

        if result.nil?
          Result.new(nil, "Failed to execute ffmpeg. Please make sure that FFmpeg is installed.")
        elsif !result
          Result.new(nil, "ffmpeg failed to encode #{output_path}.")
        elsif !File.exist?(output_path) || File.size(output_path).zero?
          Result.new(nil, "ffmpeg did not produce #{output_path}.")
        else
          Result.new(output_path, nil)
        end
      end
    end
  end
end
