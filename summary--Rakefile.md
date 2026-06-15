<!-- hash: Rakefile-v1 -->
# Rakefile

## Tasks

- `test` - `Rake::TestTask.new(:test)` libs `test`, `lib`. `test_files = FileList['test/**/*_test.rb', 'test/**/test_*.rb'].exclude('test/mvm/**').uniq`. `warning = false`.
- `rubocop` - `RuboCop::RakeTask.new`.
- `test_live` - `sh({ 'LIVE' => '1' }, 'bundle', 'exec', 'rake', 'test')`.
- `default` - depends on `test rubocop`.
- `build` - `gem build mixin_bot.gemspec`.
- `install` - depends on `build`, runs `gem install mixin_bot-<version>.gem`.
- `uninstall` - `gem uninstall mixin_bot`.
- `publish` - depends on `build`, runs `gem push mixin_bot-<version>.gem`.
- `clean` - `rm *.gem`.
- `rdoc` - `RDoc::Task.new(:rdoc)`, main = `README.md`, rdoc_dir = `doc`, includes `lib/**/*.rb`, `MIT-LICENSE`. `rdoc.options << '--line-numbers'`, `--charset=UTF-8`.
- `doc` - alias for `rdoc`.

`GEM_NAME = 'mixin_bot'`, `GEM_VERSION = MixinBot::VERSION`.

`Dir.glob('lib/tasks/**/*.rake').each { |r| load r }` loads custom tasks.
