## Unreleased

* Record with `Page.startScreenRecording` on Chrome 153+. Chrome encodes the video itself as an `.mp4` file, so FFmpeg is no longer needed. Older Chrome versions fall back to the screencast (`.webm`, requires FFmpeg). `TestRecorder.frame_rate` (default: 25) sets the frame rate, and `jpeg_quality` and `every_nth_frame` now only apply to the screencast fallback

## 0.4.0 - 2026-08-30

* Record each frame with its own timestamp so that videos play back at the same speed as the test

## 0.3.0 - 2026-08-23

* Reduce recording overhead
* Make recording JPEG quality, max dimension and screencast frame interval configurable
* Explicitly encode videos with VP8 to avoid relying on ffmpeg's default codec
* Sanitize characters that can't use for video file names
* Stop recording a video for a skipped Rails system test

## 0.2.0 - 2023-08-23

* Add support for aggregate_failures #21 (@willnet)
