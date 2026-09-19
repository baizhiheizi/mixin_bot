# frozen_string_literal: true

namespace :mixin_bot do
  desc 'Poll Mixin outputs for the default bot (or the given [bot_name]) and enqueue processor jobs'
  task :poller, [:bot] => :environment do |_task, args|
    # Processor classes live in app/mixin/processors; eager load so discovery
    # sees them (the poller process never references them directly).
    Rails.application.eager_load!

    api = args[:bot] ? MixinBot.bot(args[:bot]) : MixinBot.api
    poller = MixinBot::Outputs::Poller.new(
      api:,
      interval: Integer(ENV.fetch('MIXIN_BOT_POLL_INTERVAL', 5))
    )

    %w[TERM INT].each { |signal| trap(signal) { poller.stop } }

    MixinBot::Outputs.logger.call(:info, "poller started (pid=#{Process.pid})")
    poller.run
    MixinBot::Outputs.logger.call(:info, 'poller stopped')
  end
end
