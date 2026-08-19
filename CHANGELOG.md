## Unreleased

* Reduce recording overhead
* Make recording JPEG quality, max dimension and screencast frame interval configurable
* Explicitly encode videos with VP8 to avoid relying on ffmpeg's default codec
* Sanitize characters that can't use for video file names
* Stop recording a video for a skipped Rails system test

## 0.2.0 - 2023-08-23

* Add support for aggregate_failures #21 (@willnet)
