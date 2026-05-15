# frozen_string_literal: true

require 'digest'
require 'json'
require 'securerandom'
require 'uri'
require 'jose'

require_relative 'conversation_stub_state'

##
# Default WebMock responses for +https://api.mixin.one+ so default +rake test+ runs
# fully offline. Set +ENV['LIVE']=1+ to use a real +config.yml+ and disable stubs.
#
module MixinApiStubs
  module_function

  RAW_TX_HEX = '777700021700941284a95f31b25ec8c546008f208f88eee4419ccdcdbe6e3195e60128ca0001d8d911945795539e8ac26721de6c6ab86be4e2ccc423b4d41f60728087cc20d0000000000000000000010000000405f5e1000003f899a7fb9f7913d71ab49b005afd3a46a0d9eaf2eae5771cadd3a7962875a428a76f042f00942220d82ad39757d4b46d812b5df942fb7dcb88cf1b357bd02b598cd6eccfe1a8d5af4416b470e47e999c84a2c6f4e59226a781f7e8677b66503b698c04d7a973e292c951132f8338aae47da934f7b9d0f8dec5ccddfadf2e9a780003fffe02000000264e464f000020a0955c3a0c85fa43e9601963a77a3c44fa13bb250800899d379cab8dff786b57ffffff01fb785885a09bf6b5afa8b4fa3fca044785ab325580c25490244aec038a9e2befdcc27c9c234c7bd797c87f4fcbddebc977520f7560ab7a627ce85e2a05720f0a00000101'

  def register!
    WebMock.enable!

    WebMock.stub_request(:put, 'https://offline-upload.test/put').to_return(status: 204, body: '')
    WebMock.stub_request(:any, /api\.mixin\.one/).to_return do |request|
      body = route(request)
      { status: 200, headers: { 'Content-Type' => 'application/json', 'X-Request-Id' => 'test', 'X-Server-Time' => '0' },
        body: JSON.generate(body) }
    end
  end

  def parse_json_body(request)
    b = request.body
    return nil if b.blank?

    JSON.parse(b)
  rescue JSON::ParserError
    nil
  end

  def route(request)
    method = request.method.downcase.to_sym
    uri = URI(request.uri)
    path = uri.path
    json_body = parse_json_body(request)
    parsed_body = json_body.is_a?(Hash) ? json_body : {}
    parsed_array = json_body.is_a?(Array) ? json_body : nil
    q =
      if uri.query.present?
        URI.decode_www_form(uri.query).to_h
      else
        {}
      end

    stub_seed = Digest::SHA256.digest('mixin_bot:stub:sessions')[0, 32]
    stub_kp = JOSE::JWA::Ed25519.keypair(stub_seed)
    stub_pk = Base64.urlsafe_encode64(JOSE::JWA::Ed25519.pk_to_curve25519(stub_kp[0]), padding: false)

    if method == :get && path == '/me'
      return { 'data' => { 'user_id' => MixinBot.config.app_id, 'full_name' => 'Offline Bot', 'identity_number' => '0' },
               'error' => nil }
    end
    if method == :get && path == '/safe/me'
      return { 'data' => { 'user_id' => MixinBot.config.app_id, 'full_name' => 'Offline Safe' }, 'error' => nil }
    end
    return { 'data' => [], 'error' => nil } if method == :get && path == '/friends'

    if method == :post && path == '/me'
      return { 'data' => { 'full_name' => parsed_body['full_name'], 'user_id' => MixinBot.config.app_id },
               'error' => nil }
    end
    if method == :post && path == '/payments'
      return { 'data' => {}, 'error' => nil } unless parsed_body.is_a?(Hash)

      if parsed_body['opponent_multisig']
        return { 'data' => {
          'type' => 'payment',
          'trace_id' => parsed_body['trace_id'],
          'code_id' => SecureRandom.uuid,
          'status' => 'pending'
        }, 'error' => nil }
      end

      trace = parsed_body['trace_id']
      status = trace == 'de72d37a-b867-481f-90b4-cb5f06926c8b' ? 'paid' : 'pending'
      return { 'data' => { 'status' => status, 'trace_id' => trace }, 'error' => nil }
    end
    if method == :get && path.start_with?('/codes/')
      code_id = path.delete_prefix('/codes/')
      return { 'data' => { 'code_id' => code_id, 'type' => 'payment', 'status' => 'paid' }, 'error' => nil }
    end
    if method == :post && path == '/conversations'
      rid = parsed_body.dig('participants', 0, 'user_id') || TEST_UID
      sid = SecureRandom.uuid
      cid = parsed_body['conversation_id']
      if parsed_body['category'] == 'GROUP'
        g = ConversationStubState.group(cid)
        g['name'] = parsed_body['name'].to_s
        g['announcement'] = parsed_body['announcement'].to_s
        g['participants'] = (parsed_body['participants'] || []).map do |p|
          h = p.is_a?(Hash) ? p.stringify_keys : {}
          h.merge('role' => '')
        end
        return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil }
      end

      return { 'data' => {
        'conversation_id' => cid,
        'participant_sessions' => [
          { 'user_id' => rid, 'session_id' => sid, 'public_key' => stub_pk }
        ]
      }, 'error' => nil }
    end
    return { 'data' => { 'state' => 'SUCCESS' }, 'error' => nil } if method == :post && path == '/encrypted_messages'

    if method == :post && path == '/safe/keys'
      list = parsed_array || []
      return { 'data' => list.map { { 'mask' => '33' * 32, 'keys' => ['44' * 32] } }, 'error' => nil }
    end
    if method == :get && path =~ %r{\A/safe/outputs/[^/]+\z}
      oid = path.split('/').last
      return { 'data' => {
        'output_id' => oid,
        'amount' => '10.0',
        'asset_id' => CNB_ASSET_ID,
        'transaction_hash' => 'ab' * 32,
        'output_index' => 0,
        'receivers' => [MixinBot.config.app_id],
        'receivers_threshold' => 1
      }, 'error' => nil }
    end
    if method == :get && path == '/safe/outputs'
      st = q['state'].presence || 'unspent'
      aid_filter = q['asset'].presence
      xin_id = 'c94ac88f-4671-3976-b60a-09064f1811e8'

      if aid_filter == xin_id
        return { 'data' => [
          {
            'output_id' => 'xin-utxo-1',
            'transaction_hash' => 'ef' * 32,
            'output_index' => 0,
            'amount' => '1000.0',
            'asset_id' => xin_id,
            'receivers' => [MixinBot.config.app_id],
            'receivers_threshold' => 1,
            'state' => st
          }
        ], 'error' => nil }
      end

      if st == 'signed'
        return { 'data' => [
          {
            'output_id' => 'signed-coll-1',
            'signed_tx' => RAW_TX_HEX,
            'inscription_hash' => 'ff' * 32,
            'token_id' => 'abfe580a-1fa0-3237-8c43-52c7de5c80ae',
            'transaction_hash' => 'aa' * 32,
            'output_index' => 0,
            'amount' => '1',
            'asset_id' => CNB_ASSET_ID,
            'receivers' => [TEST_UID],
            'receivers_threshold' => 1,
            'state' => 'signed'
          }
        ], 'error' => nil }
      end

      return { 'data' => [
        {
          'output_id' => 'plain-utxo-1',
          'transaction_hash' => 'ab' * 32,
          'output_index' => 0,
          'amount' => '10.0',
          'asset_id' => CNB_ASSET_ID,
          'receivers' => [MixinBot.config.app_id],
          'receivers_threshold' => 1,
          'state' => st
        },
        {
          'output_id' => 'coll-utxo-1',
          'transaction_hash' => 'cd' * 32,
          'output_index' => 0,
          'amount' => '1',
          'asset_id' => CNB_ASSET_ID,
          'inscription_hash' => 'ee' * 32,
          'token_id' => 'abfe580a-1fa0-3237-8c43-52c7de5c80ae',
          'receivers' => [MixinBot.config.app_id],
          'receivers_threshold' => 1,
          'state' => 'unspent'
        }
      ], 'error' => nil }
    end
    if method == :post && path == '/multisigs/requests'
      return { 'data' => { 'signers' => [], 'request_id' => SecureRandom.uuid }, 'error' => nil }
    end

    if method == :post && path == '/external/kernel'
      m = parsed_body['method']
      params = parsed_body['params'] || []
      case m
      when 'gettransaction', 'getutxo'
        h = params[0]
        return { 'data' => { 'hash' => h }, 'error' => nil }
      when 'sendrawtransaction'
        return { 'data' => { 'hash' => 'deadbeef' }, 'error' => nil }
      when 'getsnapshot'
        return { 'data' => { 'snapshot' => {} }, 'error' => nil }
      when 'listsnapshots', 'listmintworks', 'listmintdistributions'
        return { 'data' => [], 'error' => nil }
      end
    end
    if method == :post && path == '/messages'
      src = parsed_array&.first || parsed_body
      src = {} unless src.is_a?(Hash)
      mid = src['message_id'] || SecureRandom.uuid
      return { 'data' => { 'message_id' => mid }, 'error' => nil }
    end
    if method == :get && path =~ %r{\A/attachments/[^/]+\z}
      aid = path.split('/').last
      return { 'data' => { 'attachment_id' => aid, 'mime_type' => 'image/png' }, 'error' => nil }
    end
    if method == :post && path == '/attachments'
      aid = SecureRandom.uuid
      return { 'data' => {
        'type' => 'attachment',
        'attachment_id' => aid,
        'upload_url' => 'https://offline-upload.test/put',
        'view_url' => 'https://offline-upload.test/view'
      }, 'error' => nil }
    end
    return { 'data' => { 'verified' => true }, 'error' => nil } if method == :post && path == '/pin/verify'
    return { 'data' => [], 'error' => nil } if method == :get && path == '/assets'

    if method == :get && path.start_with?('/assets/')
      aid = path.delete_prefix('/assets/')
      return { 'data' => { 'asset_id' => aid, 'symbol' => 'TST' }, 'error' => nil }
    end
    if method == :get && path.start_with?('/network/assets/')
      aid = path.delete_prefix('/network/assets/')
      return { 'data' => { 'asset_id' => aid, 'price_usd' => '1' }, 'error' => nil }
    end
    return { 'data' => [], 'error' => nil } if method == :get && path =~ %r{\A/users/[^/]+/apps/favorite\z}

    if method == :get && path.start_with?('/users/')
      uid = path.delete_prefix('/users/')
      return { 'data' => { 'user_id' => uid, 'full_name' => 'User' }, 'error' => nil }
    end
    if method == :get && path.start_with?('/search/')
      return { 'data' => { 'user_id' => TEST_UID, 'identity_number' => TEST_MIXIN_ID }, 'error' => nil }
    end

    if method == :post && path == '/users/fetch'
      list = parsed_array || []
      return { 'data' => list.map { |fetched_uid| { 'user_id' => fetched_uid, 'full_name' => 'U' } }, 'error' => nil }
    end
    if method == :get && path == '/safe/snapshots'
      return { 'data' => [{ 'type' => 'snapshot', 'snapshot_id' => 'safe-snap-1' }], 'error' => nil }
    end
    return { 'data' => { 'sent' => true }, 'error' => nil } if method == :post && path == '/safe/snapshots/notifications'
    if method == :get && path == '/network/snapshots'
      return { 'data' => [{ 'type' => 'snapshot', 'snapshot_id' => 'net-snap-1' }], 'error' => nil }
    end

    if method == :get && path =~ %r{\A/network/snapshots/[^/]+\z}
      sid = path.split('/').last
      return { 'data' => { 'snapshot_id' => sid, 'type' => 'snapshot' }, 'error' => nil }
    end
    if method == :get && path == '/snapshots'
      return { 'data' => [{ 'type' => 'transfer', 'trace_id' => 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb' }], 'error' => nil }
    end

    if method == :get && path.start_with?('/safe/inscriptions/items/')
      tid = path.delete_prefix('/safe/inscriptions/items/')
      return { 'data' => { 'token_id' => tid, 'nfo' => 'aa' * 64 }, 'error' => nil }
    end
    if method == :get && path.start_with?('/safe/inscriptions/collections/')
      cid = path.delete_prefix('/safe/inscriptions/collections/')
      return { 'data' => { 'collection_id' => cid, 'name' => 'col' }, 'error' => nil }
    end
    return { 'data' => { 'request_id' => SecureRandom.uuid }, 'error' => nil } if method == :post && path == '/collectibles/requests'
    return { 'data' => { 'signed' => true }, 'error' => nil } if method == :post && path =~ %r{\A/collectibles/requests/[^/]+/sign\z}
    return { 'data' => { 'unlocked' => true }, 'error' => nil } if method == :post && path =~ %r{\A/collectibles/requests/[^/]+/unlock\z}

    if method == :get && path.start_with?('/collectibles/tokens/')
      tid = path.delete_prefix('/collectibles/tokens/')
      return { 'data' => { 'token_id' => tid }, 'error' => nil }
    end
    if method == :get && path.start_with?('/collectibles/collections/')
      cid = path.delete_prefix('/collectibles/collections/')
      return { 'data' => { 'collection_id' => cid }, 'error' => nil }
    end
    return { 'data' => [], 'error' => nil } if method == :get && path == '/collectibles/outputs'
    return { 'data' => [], 'error' => nil } if method == :get && path == '/multisigs/outputs'

    if method == :post && path == '/outputs'
      return { 'data' => {
        'type' => 'ghost_key',
        'mask' => '11' * 32,
        'keys' => ['22' * 32]
      }, 'error' => nil }
    end
    return { 'data' => { 'withdrawal_id' => SecureRandom.uuid }, 'error' => nil } if method == :post && path == '/withdrawals'
    return { 'data' => [], 'error' => nil } if method == :get && path == '/withdrawals'

    if method == :get && path.start_with?('/addresses/') && !path.end_with?('/delete')
      aid = path.delete_prefix('/addresses/')
      return { 'data' => { 'address_id' => aid, 'label' => 'x', 'destination' => WITHDRAW_ETH_ADDRESS }, 'error' => nil }
    end
    if method == :post && path == '/addresses'
      dest = parsed_body['destination']
      return { 'data' => {
        'address_id' => SecureRandom.uuid,
        'label' => parsed_body['label'],
        'destination' => dest
      }, 'error' => nil }
    end
    return { 'data' => {}, 'error' => nil } if method == :post && path =~ %r{\A/addresses/[^/]+/delete\z}
    return { 'data' => { 'app_id' => MixinBot.config.app_id }, 'error' => nil } if method == :get && path == '/authorizations'
    if method == :post && path == '/oauth/authorize'
      return { 'data' => { 'authorization_id' => SecureRandom.uuid, 'code' => 'test-code' }, 'error' => nil }
    end
    return { 'data' => { 'access_token' => 'at', 'refresh_token' => 'rt' }, 'error' => nil } if method == :post && path == '/oauth/token'
    return { 'data' => { 'app_id' => path.split('/')[2] }, 'error' => nil } if method == :post && path =~ %r{\A/apps/[^/]+/favorite\z}
    return { 'data' => true, 'error' => nil } if method == :post && path =~ %r{\A/apps/[^/]+/unfavorite\z}
    return { 'data' => { 'app_id' => parsed_body['app_id'] }, 'error' => nil } if method == :post && path == '/apps/favorite'
    return { 'data' => true, 'error' => nil } if method == :post && path == '/apps/unfavorite'
    return { 'data' => [], 'error' => nil } if method == :get && path == '/external/transactions'

    if method == :post && path == '/transactions'
      tid = parsed_body['trace_id']
      return { 'data' => { 'transaction_hash' => 'aa' * 32, 'trace_id' => tid }, 'error' => nil }
    end
    if method == :post && path == '/safe/transaction/requests'
      list = parsed_array || []
      rid = (list.first || {})['request_id']
      raw = (list.first || {})['raw'].to_s
      input_count = begin
        decoded = MixinBot.utils.decode_raw_transaction(raw)
        ins = decoded[:inputs] || decoded['inputs']
        ins.is_a?(Array) ? ins.size : 1
      rescue StandardError
        1
      end
      input_count = 1 if input_count < 1
      return { 'data' => [{
        'request_id' => rid,
        'state' => 'pending',
        'views' => Array.new(input_count) { '55' * 32 }
      }], 'error' => nil }
    end
    if method == :post && path == '/safe/transactions'
      rid = (parsed_array&.first || {})['request_id']
      return { 'data' => [{ 'request_id' => rid, 'transaction_hash' => 'aa' * 32, 'raw' => RAW_TX_HEX }], 'error' => nil }
    end
    if method == :post && path == '/transfers'
      tid = parsed_body['trace_id']
      return { 'data' => { 'trace_id' => tid, 'status' => 'success' }, 'error' => nil }
    end
    if method == :get && path.start_with?('/transfers/trace/')
      tid = path.delete_prefix('/transfers/trace/')
      return { 'data' => { 'trace_id' => tid }, 'error' => nil }
    end

    if method == :get && path.start_with?('/conversations/')
      sub = path.delete_prefix('/conversations/')
      if sub.include?('/')
        # participants routes etc — fall through to posts below for non-GET
      else
        cid = sub
        g = ConversationStubState.group(cid)
        return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil } if g['name'].present? || g['participants'].any?

        return { 'data' => { 'conversation_id' => cid, 'code_id' => SecureRandom.uuid, 'participants' => [],
                             'name' => '', 'announcement' => '' }, 'error' => nil }
      end
    end

    if method == :post && path =~ %r{\A/conversations/[^/]+\z}
      cid = path.split('/')[2]
      g = ConversationStubState.group(cid)
      g['name'] = parsed_body['name'] if parsed_body['name']
      g['announcement'] = parsed_body['announcement'] if parsed_body['announcement']
      return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil }
    end
    if method == :post && path =~ %r{/conversations/[^/]+/rotate\z}
      cid = path.split('/')[2]
      g = ConversationStubState.touch_rotate!(cid)
      return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil }
    end
    if method == :post && path =~ %r{/conversations/[^/]+/participants/ROLE\z}
      cid = path.split('/')[2]
      g = ConversationStubState.group(cid)
      role_payload = parsed_array || (parsed_body.is_a?(Array) ? parsed_body : [])
      role_payload.each do |p|
        uid = p['user_id']
        role = p['role']
        entry = g['participants'].find { |x| x['user_id'] == uid }
        if entry
          entry['role'] = role
        else
          g['participants'] << (p.is_a?(Hash) ? p.stringify_keys : {})
        end
      end
      return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil }
    end
    if method == :post && path =~ %r{/conversations/[^/]+/participants/REMOVE\z}
      cid = path.split('/')[2]
      g = ConversationStubState.group(cid)
      uids = (parsed_array || (parsed_body.is_a?(Array) ? parsed_body : [])).map { |x| x['user_id'] }
      g['participants'].reject! { |x| uids.include?(x['user_id']) }
      return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil }
    end
    if method == :post && path =~ %r{/conversations/[^/]+/participants/ADD\z}
      cid = path.split('/')[2]
      g = ConversationStubState.group(cid)
      (parsed_array || (parsed_body.is_a?(Array) ? parsed_body : [])).each do |p|
        ph = p.is_a?(Hash) ? p.stringify_keys : {}
        g['participants'] << ph.merge('role' => '') unless g['participants'].any? { |x| x['user_id'] == ph['user_id'] }
      end
      return { 'data' => JSON.parse(JSON.generate(g)), 'error' => nil }
    end
    return { 'data' => nil, 'error' => nil } if method == :post && path =~ %r{/conversations/[^/]+/exit\z}

    { 'data' => {}, 'error' => nil }
  end
end
