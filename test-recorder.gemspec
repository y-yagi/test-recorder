require_relative 'lib/test_recorder/version'

Gem::Specification.new do |spec|
  spec.name          = "test-recorder"
  spec.version       = TestRecorder::VERSION
  spec.authors       = ["Yuji Yaginuma"]
  spec.email         = ["yuuji.yaginuma@gmail.com"]

  spec.summary       = %q{Automatically record videos when tests failed.}
  spec.homepage      = "http://github.com/y-yagi/test-recorder"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "activesupport"
  spec.add_dependency "selenium-webdriver", ">= 4.0"
  spec.add_dependency "selenium-devtools"
  spec.add_development_dependency "activesupport-testing-metadata"
end
