require_relative 'lib/videotest/recorder/version'

Gem::Specification.new do |spec|
  spec.name          = "videotest-recorder"
  spec.version       = Videotest::Recorder::VERSION
  spec.authors       = ["Yuji Yaginuma"]
  spec.email         = ["yuuji.yaginuma@gmail.com"]

  spec.summary       = %q{Automatically record videos when tests failed.}
  spec.homepage      = "http://github.com/y-yagi/videotest-recorder"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "headless"
  spec.add_dependency "railties"
end
