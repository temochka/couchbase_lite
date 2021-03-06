lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'couchbase_lite/version'

Gem::Specification.new do |spec|
  spec.name          = 'couchbase_lite'
  spec.version       = CouchbaseLite::VERSION
  spec.authors       = ['Artem Chistyakov']
  spec.email         = ['chistyakov.artem@gmail.com']

  spec.summary       = %q{A Ruby wrapper for Couchbase Lite Core}
  spec.homepage      = 'https://github.com/temochka/couchbase-lite-ruby'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w(lib)

  spec.add_dependency 'ffi', '>= 1.9.24', '< 2.0'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'faye-websocket', '~> 0.10.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'thin', '~> 1.7.0'
end
