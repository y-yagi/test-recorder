# TestRecorder

Record a video automatically when tests failed. The videos are generated in `tmp/videos` directory.

![CI](https://github.com/y-yagi/test-recorder/workflows/CI/badge.svg)
[![Gem Version](https://badge.fury.io/rb/test-recorder.svg)](http://badge.fury.io/rb/test-recorder)


## Requirements

This gem depends on Xvfb and FFmpeg. Please install those packages.

On Debian/Ubuntu:

```bash
sudo apt-get install xvfb ffmpeg
```

## Supported libraries

Rails system tests and RSpec(System Spec and Feature Spec).

## Limitations

Currently, this gem doesn't support a headless driver. You need to run a browser with a GUI. Tests automatically run with headless via this gem.

## Usage

### 1: Install the gem

Using Bundler, add the following to your Gemfile:

```ruby
gem 'test-recorder', group: :test
```

### 2: Load library into your tests

#### Rails

```ruby
require 'test_recorder/rails'
```

#### RSpec

```ruby
require 'test_recorder/rspec'
```
