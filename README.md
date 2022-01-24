# TestRecorder

Record a video automatically when tests failed. The videos are generated in `tmp/videos` directory.

[![Build Status](https://github.com/y-yagi/test-recorder/workflows/CI/badge.svg)](https://github.com/y-yagi/test-recorder/actions)
[![Gem Version](https://badge.fury.io/rb/test-recorder.svg)](http://badge.fury.io/rb/test-recorder)


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

```ruby
# test/test_helper.rb
require 'test_recorder/rspec'

TestRecorder.disable!
```

```ruby
it "test to something", test_recorder: true do
  # ...
end

