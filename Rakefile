# frozen_string_literal: true

require 'bundler'
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files =
    FileList[
      'test/**/*_test.rb',
      'test/**/test_*.rb'
    ].exclude('test/mvm/**').uniq
  t.warning = false
end

require 'rubocop/rake_task'

RuboCop::RakeTask.new

desc 'Run tests with LIVE=1 (real network; requires test/config.yml)'
task :test_live do
  sh({ 'LIVE' => '1' }, 'bundle', 'exec', 'rake', 'test')
end

task default: %i[test rubocop]

GEM_NAME = 'mixin_bot'
GEM_VERSION = MixinBot::VERSION

desc 'Build gem'
task :build do
  system "gem build #{GEM_NAME}.gemspec"
end

desc 'Build & install gem'
task install: :build do
  system "gem install #{GEM_NAME}-#{GEM_VERSION}.gem"
end

desc 'Uninstall gem'
task :uninstall do
  system "gem uninstall #{GEM_NAME}"
end

desc 'Build & publish gem'
task publish: :build do
  system "gem push #{GEM_NAME}-#{GEM_VERSION}.gem"
end

desc 'clean built gems'
task :clean do
  system 'rm *.gem'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_dir = 'doc'
  rdoc.title = 'MixinBot - Ruby SDK for Mixin Network'
  rdoc.options << '--line-numbers'
  rdoc.options << '--charset=UTF-8'
  rdoc.rdoc_files.include('README.md', 'MIT-LICENSE')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Generate documentation (alias for rdoc)'
task doc: :rdoc
