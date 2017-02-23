# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'debug_socket/version'

Gem::Specification.new do |spec|
  spec.name          = "debug_socket"
  spec.version       = DebugSocket::VERSION
  spec.authors       = ["Andrew Lazarus"]
  spec.email         = ["lazarus@squareup.com"]

  spec.summary       = "Debug Socket for running ruby processes"
  spec.homepage      = "https://github.com/square/debug_socket"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
