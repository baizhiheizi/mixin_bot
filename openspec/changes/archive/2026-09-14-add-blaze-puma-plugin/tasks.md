## 1. Blaze reactor core

- [x] 1.1 Add `MixinBot.blaze_handler` (callable) and `MixinBot.blaze_ack_policy` (`:on_receipt` default / `:after_handler`) to configuration in `lib/mixin_bot.rb`; verify existing `rake test` still passes and a smoke require shows the new accessors
- [x] 1.2 Extract the loop from `examples/blaze_async.rb` into `MixinBot::Blaze::Reactor` (`lib/mixin_bot/blaze/reactor.rb`): injectable API/connection factory, keepalive ping fiber, `list_pending_message` on open, serial read → decode → handler → ack-per-policy loop; verify a unit test with a fake connection drives one message through handler + ack
- [x] 1.3 Add reconnect with bounded exponential backoff (1 s → 30 s cap, reset after stable period) and handler-exception isolation (log + continue); verify unit tests simulate a dropped connection and a raising handler
- [x] 1.4 Verify the gem still loads without Puma installed: `ruby -Ilib -e "require 'mixin_bot'"` in an environment without puma on the load path

## 2. Puma plugin shell

- [x] 2.1 Add `puma` to the Gemfile (dev/test only) and confirm `rake test` unaffected; verify `bundle install` succeeds without touching the gemspec
- [x] 2.2 Create `lib/puma/plugin/mixin_blaze.rb` registering via `Puma::Plugin.create` with `start(launcher)`, and extend `Puma::DSL` with `mixin_blaze_mode` (`:fork` default, `:async`); verify `plugin :mixin_blaze` resolves the plugin in a Puma config load smoke test
- [x] 2.3 Implement Puma 6/7 lifecycle branching (`on_booted`/`on_stopped`/`on_restart` vs `after_booted`/`after_stopped`/`before_restart`, version-gated like Solid Queue); verify both hook sets fire in unit tests with stubbed launcher events
- [x] 2.4 Implement async mode: start the reactor in a background thread (`in_background { Async { ... } }`) at booted, stop (task stop + connection close) at stopped/restart; verify with a stubbed launcher that the thread starts and stops cleanly
- [x] 2.5 Implement fork mode: fork the reactor child at booted, supervise it from an `in_background` thread (child death → `Process.kill(:INT, $$)`), child monitors master via `Process.ppid`, stop path terminates child with INT + `waitpid`, `exit!` in child; verify a smoke test boots a real `Puma::Launcher` in single mode with a stub app and a fake reactor, exercising fork + shutdown
- [x] 2.6 Implement boot-time precondition errors through `launcher.log_writer`: cluster without `preload_app!` (name the fix, do not start the loop) and unset handler at loop start; verify both error paths in unit tests

## 3. Docs

- [x] 3.1 Add "Running Blaze inside Puma" to README (config/puma.rb snippet, `MixinBot.blaze_handler` initializer, mode table, ack-policy guidance) and a matching section in `docs/agent/cookbook.md`; verify rendered output and that the snippet matches the implemented DSL exactly
- [x] 3.2 Document the duplicate-connection hazard (remove the standalone Blaze process when enabling the plugin) and the phased-restart handler-staleness caveat in both docs; verify wording present in README and cookbook

## 4. Final verification

- [x] 4.1 Run `rake` (tests + RuboCop) clean; verify gemspec file list includes `lib/puma/plugin/mixin_blaze.rb` via `rake build` and inspecting the built gem contents
- [ ] 4.2 Live smoke (manual, needs real credentials): boot a single-mode Puma app with the plugin against real Blaze, send the bot a message, observe handler log + ack + clean SIGTERM shutdown; record multi-connection delivery semantics observed (fan-out vs load-balance) to resolve the design open question
