# frozen_string_literal: true

# Minimal ActiveRecord-ish host for MixinBot::Transfers::Model tests.
class FakeTransfer
  class << self
    attr_accessor :reconciling_records, :reconcile_hook

    def validates(*); end

    def reconciling
      records = reconciling_records || []
      Class.new do
        define_method(:find_each) { |&block| records.each(&block) }
      end.new
    end
  end

  include MixinBot::Transfers::Model

  attr_accessor :state, :previous_state, :transaction_hash, :error, :transitioned_at,
                :trace_id, :recipient_id, :asset_id, :amount, :memo, :bot_app_id

  def initialize(trace_id: '11111111-2222-4333-8444-555555555555', recipient_id: nil, asset_id: nil,
                 amount: nil, memo: nil, state: 'pending')
    @trace_id = trace_id
    @recipient_id = recipient_id
    @asset_id = asset_id
    @amount = amount
    @memo = memo
    @state = state
  end

  def reconcile!
    hook = self.class.reconcile_hook
    hook ? hook.call(self) : super
  end

  def update!(attrs)
    attrs.each { |key, value| send("#{key}=", value) }
    self
  end
end
