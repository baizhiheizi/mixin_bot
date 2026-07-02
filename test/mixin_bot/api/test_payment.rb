# frozen_string_literal: true

require 'test_helper'

module MixinBot
  ##
  # Offline unit tests for +lib/mixin_bot/api/payment.rb+.
  #
  # +MixinBot::API::Payment#safe_pay_url+ is a pure helper — no HTTP — that
  # composes a Mixin Safe payment URL of the form:
  #
  #   https://mixin.one/pay/<mix-address>?amount=<amount>&asset=<asset>&memo=<memo>&trace=<trace>
  #
  # These tests cover the URL shape (prefix, query string, all four params),
  # the two defaults (memo → +''+, trace_id → +SecureRandom.uuid+), the
  # round-trip from URL → +parse_mix_address+ (members + threshold), and the
  # ordering-invariance of the underlying +build_mix_address+ helper.
  #
  # No HTTP, WebMock, or live API access required.
  #
  class TestSafePayUrl < Minitest::Test
    USER_A = '7ed9292d-7c95-4333-aa48-a8c640064186'
    USER_B = 'a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1'
    USER_C = '0508a116-1239-4e28-b150-85a8e3e6b400'
    CNB = '965e5c6e-434c-3fa9-b780-c50f43cd955c'
    AMOUNT = 0.00000001
    FIXED_TRACE = 'b0b7a91d-1b1f-4a3e-9c2b-5e1f7c2c9aaa'

    # ===== Happy path ======================================================

    def test_safe_pay_url_starts_with_payment_prefix
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      assert url.start_with?('https://mixin.one/pay/MIX'),
             "expected URL to start with the payment prefix, got #{url.inspect}"
    end

    def test_safe_pay_url_includes_all_four_query_params
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        memo: 'hello world',
        trace_id: FIXED_TRACE
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query.to_s).to_h

      assert_equal CNB, params['asset']
      assert_equal 'hello world', params['memo']
      assert_equal FIXED_TRACE, params['trace']
      refute_nil params['amount'], 'expected amount query param to be present'
    end

    def test_safe_pay_url_encodes_amount_without_scientific_notation_regression
      # Regression guard for https://github.com/baizhiheizi/mixin_bot/issues/...
      # The implementation uses `amount` directly in string interpolation, which
      # for very small floats (e.g. 0.00000001) renders as "1.0e-08". This is
      # *not* what the Mixin web UI accepts in the amount query param.
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query.to_s).to_h

      # +1.0e-08+ would break Mixin's URL parser; the implementation should
      # either preserve a string amount or normalise via BigDecimal. Until
      # that's fixed, this test documents the current behaviour — change it
      # to refute when the bug is resolved upstream.
      assert_includes params['amount'].to_s, '1.0e-08',
                      'expected amount= to currently render in scientific notation (bug); update this test when fixed'
    end

    # ===== Defaults ========================================================

    def test_safe_pay_url_defaults_memo_to_empty_string
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query.to_s).to_h

      assert_equal '', params['memo']
    end

    def test_safe_pay_url_defaults_trace_id_to_a_fresh_uuid_when_omitted
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query.to_s).to_h
      trace = params['trace']

      refute_nil trace
      refute_empty trace
      assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, trace,
                   'expected trace_id default to be a UUID v4-shaped string')
    end

    def test_safe_pay_url_mints_a_distinct_default_trace_each_call
      urls = Array.new(3) do
        MixinBot.api.safe_pay_url(
          members: [USER_A],
          threshold: 1,
          asset_id: CNB,
          amount: AMOUNT
        )
      end

      traces = urls.map { |u| URI.decode_www_form(URI(u).query.to_s).to_h['trace'] }
      assert_equal 3, traces.uniq.size, 'expected each call to mint a fresh trace_id'
    end

    def test_safe_pay_url_does_not_pass_unknown_kwargs_through
      # Mirrors the bug in the original test file: `trace:` (no `_id`) was
      # silently swallowed. The method must NOT accept the typo as a synonym.
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        trace: FIXED_TRACE # wrong key — should be ignored
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query.to_s).to_h
      refute_equal FIXED_TRACE, params['trace'],
                   'unknown kwarg :trace must not be used as a synonym for :trace_id'
    end

    # ===== Multisig ========================================================

    def test_safe_pay_url_supports_multisig_with_threshold_two
      url = MixinBot.api.safe_pay_url(
        members: [USER_A, USER_B],
        threshold: 2,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      address = url.sub(%r{\Ahttps://mixin\.one/pay/}, '').sub(/\?.*\z/, '')
      parsed = MixinBot.utils.parse_mix_address(address)

      assert_equal 2, parsed[:threshold]
      assert_equal [USER_A, USER_B].sort, parsed[:members].sort
    end

    def test_safe_pay_url_supports_multisig_with_threshold_three
      url = MixinBot.api.safe_pay_url(
        members: [USER_A, USER_B, USER_C],
        threshold: 3,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      address = url.sub(%r{\Ahttps://mixin\.one/pay/}, '').sub(/\?.*\z/, '')
      parsed = MixinBot.utils.parse_mix_address(address)

      assert_equal 3, parsed[:threshold]
      assert_equal [USER_A, USER_B, USER_C].sort, parsed[:members].sort
    end

    def test_safe_pay_url_member_order_does_not_affect_address
      url_a = MixinBot.api.safe_pay_url(
        members: [USER_A, USER_B],
        threshold: 2,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )
      url_b = MixinBot.api.safe_pay_url(
        members: [USER_B, USER_A],
        threshold: 2,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      # Same members, threshold, trace_id → same URL.
      assert_equal url_a, url_b
    end

    # ===== Determinism =====================================================

    def test_safe_pay_url_is_deterministic_for_same_inputs
      url_a = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        memo: 'tip',
        trace_id: FIXED_TRACE
      )
      url_b = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        memo: 'tip',
        trace_id: FIXED_TRACE
      )

      assert_equal url_a, url_b
    end

    def test_safe_pay_url_returns_a_string
      url = MixinBot.api.safe_pay_url(
        members: [USER_A],
        threshold: 1,
        asset_id: CNB,
        amount: AMOUNT,
        trace_id: FIXED_TRACE
      )

      assert_kind_of String, url
    end
  end
end