# frozen_string_literal: true

require 'test_helper'

module MixinBot
  ##
  # Offline unit tests for +MixinBot::UrlScheme+ — pure helpers that build
  # +mixin://…+ deep links. No network is required.
  #
  # The module is small (eight public functions across 63 LoC), but two of
  # them have non-obvious encoding semantics that are worth pinning down so
  # future refactors stay byte-identical:
  #
  # * +scheme_send+ Base64-encodes the user payload, then runs the result
  #   through +URI.encode_www_form_component+ **and** +URI.encode_www_form+.
  #   The second pass percent-encodes the +%3D+ produced by the first, so
  #   round-tripping the data back out needs two decodes (one form-component,
  #   one form).
  # * +scheme_apps+ builds its query from
  #   <tt>{action: action.presence || 'open'}.merge(params || {})</tt>. Because
  #   +Hash#merge+ collapses shared keys in favour of the right-hand side, a
  #   caller-supplied +params: { action: 'x' }+ overrides the kwarg +action+.
  #   Both call sites match Go's url-scheme helper, so the behaviour is
  #   intentional.
  class TestUrlScheme < Minitest::Test
    # ===== scheme_users ===================================================

    def test_scheme_users_wraps_a_user_id
      url = MixinBot::UrlScheme.scheme_users(TEST_UID)

      assert_equal "mixin://users/#{TEST_UID}", url
    end

    def test_scheme_users_does_not_escape_uuid_dashes
      url = MixinBot::UrlScheme.scheme_users('abc-def-123-456789abcdef')

      assert_includes url, 'abc-def-123-456789abcdef'
    end

    # ===== scheme_transfer ===============================================

    def test_scheme_transfer_wraps_a_user_id
      url = MixinBot::UrlScheme.scheme_transfer(TEST_UID_2)

      assert_equal "mixin://transfer/#{TEST_UID_2}", url
    end

    # ===== scheme_pay ====================================================

    def test_scheme_pay_encodes_every_field_in_hash_insertion_order
      url = MixinBot::UrlScheme.scheme_pay(
        asset_id: ETH_ASSET_ID,
        trace_id: 'abcd1234',
        recipient_id: TEST_UID,
        memo: 'thanks',
        amount: '0.1'
      )

      # +URI.encode_www_form+ serialises hash entries in insertion order
      # (matches Go url.Values.Encode in modern Go stdlib), so the keys
      # come out in the same order they were supplied to +scheme_pay+.
      assert_equal(
        'mixin://pay?' \
        "asset=#{ETH_ASSET_ID}&trace=abcd1234&amount=0.1&recipient=#{TEST_UID}&memo=thanks",
        url
      )
    end

    def test_scheme_pay_query_is_url_decodable_into_kwarg_values
      url = MixinBot::UrlScheme.scheme_pay(
        asset_id: ETH_ASSET_ID,
        trace_id: 'abcd1234',
        recipient_id: TEST_UID,
        memo: 'thanks',
        amount: '0.1'
      )

      params = URI.decode_www_form(URI(url).query).to_h
      assert_equal ETH_ASSET_ID, params['asset']
      assert_equal 'abcd1234',    params['trace']
      assert_equal TEST_UID,      params['recipient']
      assert_equal 'thanks',      params['memo']
      assert_equal '0.1',         params['amount']
    end

    def test_scheme_pay_coerces_memo_and_amount_to_strings
      url = MixinBot::UrlScheme.scheme_pay(
        asset_id: CNB_ASSET_ID,
        trace_id: 'xx',
        recipient_id: TEST_UID,
        memo: nil,
        amount: 7
      )

      assert_includes url, 'memo='
      assert_includes url, 'amount=7'
    end

    # ===== scheme_codes ==================================================

    def test_scheme_codes_wraps_a_code_id
      url = MixinBot::UrlScheme.scheme_codes(MULTI_SIGN_CODE_ID)

      assert_equal "mixin://codes/#{MULTI_SIGN_CODE_ID}", url
    end

    # ===== scheme_snapshots ==============================================

    def test_scheme_snapshots_with_no_args_is_just_the_root
      url = MixinBot::UrlScheme.scheme_snapshots

      assert_equal 'mixin://snapshots', url
    end

    def test_scheme_snapshots_appends_snapshot_id_as_path
      url = MixinBot::UrlScheme.scheme_snapshots(snapshot_id: 'snap-1')

      assert_equal 'mixin://snapshots/snap-1', url
    end

    def test_scheme_snapshots_appends_trace_id_as_query
      url = MixinBot::UrlScheme.scheme_snapshots(trace_id: 'tr-1')

      assert_equal 'mixin://snapshots?trace=tr-1', url
    end

    def test_scheme_snapshots_with_both_args_emits_path_and_query
      url = MixinBot::UrlScheme.scheme_snapshots(snapshot_id: 'snap-1', trace_id: 'tr-1')

      assert_equal 'mixin://snapshots/snap-1?trace=tr-1', url
    end

    # ===== scheme_conversations ==========================================

    def test_scheme_conversations_with_no_args_is_just_the_root
      url = MixinBot::UrlScheme.scheme_conversations

      assert_equal 'mixin://conversations', url
    end

    def test_scheme_conversations_appends_conversation_id_as_path
      url = MixinBot::UrlScheme.scheme_conversations(conversation_id: 'conv-1')

      assert_equal 'mixin://conversations/conv-1', url
    end

    def test_scheme_conversations_appends_user_as_query
      url = MixinBot::UrlScheme.scheme_conversations(user_id: TEST_UID)

      assert_equal "mixin://conversations?user=#{TEST_UID}", url
    end

    def test_scheme_conversations_with_both_args_emits_path_and_query
      url = MixinBot::UrlScheme.scheme_conversations(
        conversation_id: 'conv-1', user_id: TEST_UID
      )

      assert_equal "mixin://conversations/conv-1?user=#{TEST_UID}", url
    end

    # ===== scheme_apps ===================================================

    def test_scheme_apps_default_action_is_open
      url = MixinBot::UrlScheme.scheme_apps(app_id: 'app-1')

      assert_equal 'mixin://apps/app-1?action=open', url
    end

    def test_scheme_apps_uses_explicit_action
      url = MixinBot::UrlScheme.scheme_apps(app_id: 'app-1', action: 'pay')

      assert_equal 'mixin://apps/app-1?action=pay', url
    end

    def test_scheme_apps_blank_action_is_treated_as_default_open
      # +nil.present?+ is false, so +action.presence || 'open'+ -> 'open'.
      url = MixinBot::UrlScheme.scheme_apps(app_id: 'app-1', action: nil)
      assert_equal 'mixin://apps/app-1?action=open', url

      url2 = MixinBot::UrlScheme.scheme_apps(app_id: 'app-1', action: '')
      assert_equal 'mixin://apps/app-1?action=open', url2
    end

    def test_scheme_apps_merges_params_alongside_action
      url = MixinBot::UrlScheme.scheme_apps(
        app_id: 'app-1',
        action: 'pay',
        params: { trace: 'tr-1', amount: '0.5' }
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h
      assert_equal 'pay', params['action']
      assert_equal 'tr-1', params['trace']
      assert_equal '0.5', params['amount']
    end

    def test_scheme_apps_params_action_overrides_explicit_action
      # Hash#merge: a caller-supplied :action in params replaces the kwarg.
      # Documented behaviour (matches Go); flag a guard test so we notice
      # if it ever changes.
      url = MixinBot::UrlScheme.scheme_apps(
        app_id: 'app-1',
        action: 'open',
        params: { action: 'pay' }
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h
      assert_equal 'pay', params['action']
    end

    def test_scheme_apps_blank_params_object_still_emits_action
      url = MixinBot::UrlScheme.scheme_apps(app_id: 'app-1', action: 'pay', params: {})

      assert_equal 'mixin://apps/app-1?action=pay', url
    end

    # ===== scheme_send ===================================================

    def test_scheme_send_with_only_category_is_minimal_url
      url = MixinBot::UrlScheme.scheme_send(category: 'image')

      assert_equal 'mixin://send?category=image', url
    end

    def test_scheme_send_coerces_category_to_string
      url = MixinBot::UrlScheme.scheme_send(category: :sticker)

      assert_includes url, 'category=sticker'
    end

    def test_scheme_send_appends_conversation_when_present
      url = MixinBot::UrlScheme.scheme_send(
        category: 'image', conversation_id: 'conv-1'
      )

      assert_equal 'mixin://send?category=image&conversation=conv-1', url
    end

    def test_scheme_send_base64_then_form_component_encodes_the_data
      data = 'hello'
      url = MixinBot::UrlScheme.scheme_send(category: 'text', data: data)

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h
      encoded = params['data']

      # data is Base64.strict_encode64'd then URI.encode_www_form_component'd.
      # The component pass turns +/=+ into %xx, so the encoded value must:
      # (a) round-trip back through URI.decode_www_form_component to a valid
      #     Base64 string, and
      # (b) Base64-decode to the original data bytes.
      once = URI.decode_www_form_component(encoded)
      assert_equal Base64.strict_encode64(data), once
      assert_equal data, Base64.strict_decode64(once)
    end

    def test_scheme_send_handles_binary_data
      data = "\x00\x01\x02\xFF\xFE".b
      url = MixinBot::UrlScheme.scheme_send(category: 'text', data: data)

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h
      once = URI.decode_www_form_component(params['data'])

      assert_equal data, Base64.strict_decode64(once)
    end

    def test_scheme_send_does_not_inline_empty_data
      url = MixinBot::UrlScheme.scheme_send(category: 'text', data: nil)

      refute_includes url, 'data='
      assert_equal 'mixin://send?category=text', url
    end

    def test_scheme_send_with_all_fields_round_trips_data
      data = '{"amount":"0.1","recipient":"x"}'
      url = MixinBot::UrlScheme.scheme_send(
        category: 'transfer',
        data: data,
        conversation_id: 'conv-99'
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h
      recovered = Base64.strict_decode64(URI.decode_www_form_component(params['data']))

      assert_equal data, recovered
      assert_equal 'conv-99', params['conversation']
      assert_equal 'transfer', params['category']
    end

    # ===== module surface ================================================

    def test_url_scheme_module_constant_is_mixin
      assert_equal 'mixin', MixinBot::UrlScheme::SCHEME
    end

    def test_all_scheme_helpers_start_with_mixin_scheme
      [
        MixinBot::UrlScheme.scheme_users('u'),
        MixinBot::UrlScheme.scheme_transfer('u'),
        MixinBot::UrlScheme.scheme_pay(asset_id: 'a', trace_id: 't', recipient_id: 'r', memo: '', amount: '1'),
        MixinBot::UrlScheme.scheme_codes('c'),
        MixinBot::UrlScheme.scheme_snapshots,
        MixinBot::UrlScheme.scheme_conversations,
        MixinBot::UrlScheme.scheme_apps(app_id: 'app'),
        MixinBot::UrlScheme.scheme_send(category: 'text')
      ].each do |url|
        assert url.start_with?('mixin://'), "#{url.inspect} should start with mixin://"
      end
    end
  end
end
