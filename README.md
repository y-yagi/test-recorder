# TestRecorder

Record a video automatically when tests failed. The videos are generated in `tmp/videos` directory.

[![Build Status](https://github.com/y-yagi/test-recorder/workflows/CI/badge.svg)](https://github.com/y-yagi/test-recorder/actions)
[![Gem Version](https://badge.fury.io/rb/test-recorder.svg)](http://badge.fury.io/rb/test-recorder)

This gem was inspired by [Record video feature of Playwright](https://playwright.dev/docs/videos).

## Requirements

This gem depends on FFmpeg. Please install that package.

On Debian/Ubuntu:

```bash
sudo apt-get install ffmpeg
```

## Supported libraries

Rails system tests and RSpec(System Spec and Feature Spec).

## Limitations

Currently, this gem only supports a Headless Chrome.

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

### Only record specific tests

`TestRecorder` records all tests by default. But if you want to limit the tests, you can do it by specifying metadata.

#### Rails

##### 1: Install the additional Gem

Using Bundler, add the following to your Gemfile:

```ruby
gem 'activesupport-testing-metadata', group: :test
```

##### 2. Disable `TestRecorder`, and specified tests with the tag

```ruby
# test/test_helper.rb
require 'test_recorder/rails'
require 'active_support/testing/metadata'

TestRecorder.disable!
```

```ruby
test "test to something", test_recorder: true do
  # ...
end
```

#### RSpec

You don't need to install other gems. Only disable `TestRecorder`, and specified tests with the tag.

```ruby
# test/test_helper.rb
require 'test_recorder/rspec'

TestRecorder.disable!
```

```ruby
it "test to something", test_recorder: true do
  # ...
end
```

### Configuration

You can change the recording quality and the max width/height (in pixels).

```ruby
TestRecorder.jpeg_quality = 80    # default: 60
TestRecorder.max_dimension = 1280 # default: 1000
```

You can also record only every Nth frame. This lowers the recording overhead
at the cost of a choppier video. The playback duration stays the same.

```ruby
TestRecorder.every_nth_frame = 3 # default: 1
```

Recording can also be moved to a separate process that connects to Chrome on
its own, so handling the frames doesn't slow down the test process. This is
opt-in:

```ruby
TestRecorder.separate_process = true # default: false
```

It helps most when spare CPU cores are available. If a separate process can't
be used (e.g. a remote browser whose CDP address isn't reachable from a new
process), it warns and falls back to recording in the test process itself.

