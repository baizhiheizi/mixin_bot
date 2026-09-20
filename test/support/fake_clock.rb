# frozen_string_literal: true

# Deterministic clock double for store/poller tests.
class FakeClock
  def initialize(start = Time.at(1_700_000_000))
    @now = start
  end

  def to_proc
    method(:now).to_proc
  end

  attr_reader :now

  def advance(seconds)
    @now += seconds
  end
end
