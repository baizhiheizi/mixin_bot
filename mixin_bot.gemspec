# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'mixin_bot/version'

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 3.2.0'

  s.name          = 'mixin_bot'
  s.version       = MixinBot::VERSION
  s.authors       = ['an-lee']
  s.email         = ['an.lee.work@gmail.com']
  s.homepage      = 'https://github.com/an-lee/mixin_bot'
  s.summary       = 'A Ruby SDK for Mixin Network'
  s.description   = 'An API wrapper for Mixin Network'
  s.license       = 'MIT'
  s.files         = Dir[
    '{app,config,db,lib}/**/*',
    'docs/agent/**/*',
    'examples/*',
    'llms.txt',
    'AGENTS.md',
    'README.md',
    'CHANGELOG.md',
    'API_COVERAGE.md',
    'MIT-LICENSE'
  ]
  s.require_paths = ['lib']
  s.executables   = ['mixinbot']

  s.add_dependency 'activesupport', '>= 7'
  s.add_dependency 'awesome_print', '~> 1.8'
  s.add_dependency 'base58', '~> 0.2'
  s.add_dependency 'bcrypt', '~> 3.1'
  s.add_dependency 'benchmark', '>= 0.4'
  s.add_dependency 'blake3-rb', '~> 1.5'
  s.add_dependency 'cli-ui', '~> 2.2'
  # 0.5.17+ pulls openssl ~> 3.3 (works on Ruby 4); older 0.5.x pinned openssl < 4 and broke Ruby 4.
  s.add_dependency 'eth', '>= 0.5.17', '< 0.6'
  s.add_dependency 'faraday', '~> 2'
  s.add_dependency 'faraday-multipart', '~> 1'
  s.add_dependency 'faraday-retry', '~> 2'
  s.add_dependency 'faye-websocket', '~> 0.11'
  s.add_dependency 'jose', '~> 1.1'
  s.add_dependency 'msgpack', '~> 1.3'
  s.add_dependency 'rbnacl', '~> 7.1'
  s.add_dependency 'sha3', '~> 2.2'
  s.add_dependency 'thor', '~> 1.0'

  s.metadata['rubygems_mfa_required'] = 'true'
end
