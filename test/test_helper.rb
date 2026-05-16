# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path('support', __dir__)

require 'webmock'
require 'minitest/autorun'
require 'yaml'

require 'mixin_bot'

require 'minitest/reporters'
Minitest::Reporters.use!

require_relative 'support/offline_config'
require_relative 'support/mixin_api_stubs'

CONFIG =
  begin
    YAML.load_file("#{File.dirname(__FILE__)}/config.yml")
  rescue StandardError
    {}
  end

TEST_UID = '7ed9292d-7c95-4333-aa48-a8c640064186'
TEST_UID_2 = 'a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1'
TEST_MIXIN_ID = '37230199'
XIN_ASSET_ID = 'c94ac88f-4671-3976-b60a-09064f1811e8'
CNB_ASSET_ID = '965e5c6e-434c-3fa9-b780-c50f43cd955c'
CNB_MIXIN_ID = 'b9f49cf777dc4d03bc54cd1367eebca319f8603ea1ce18910d09e2c540c630d8'
ETH_ASSET_ID = '43d61dcd-e413-450d-80b8-101d5e903357'
EOS_ASSET_ID = '6cfe566e-4aad-470b-8c9a-2fd35b49c68d'
WITHDRAW_ETH_ADDRESS = '0xa6c20096dee08a32398029b5eb410345f7fbbcca'
WITHDRAW_EOS_ACCOUNT_NAME = 'pxneosincome'
WITHDRAW_EOS_ACCOUNT_TAG = 'YET7JMC7'
MULTI_SIGN_CODE_ID = '4e4c7f9e-ef12-46d4-a552-4c173f2bb1ca'
MULTI_SIGN_MEMBERS = %w[0508a116-1239-4e28-b150-85a8e3e6b400 7ed9292d-7c95-4333-aa48-a8c640064186
                        a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1].freeze
MULTI_SIGN_THRESHOLD = 2

NFO_MTG = %w[4b188942-9fb0-4b99-b4be-e741a06d1ebf dd655520-c919-4349-822f-af92fabdbdf4 047061e6-496d-4c35-b06b-b0424a8a400d
             acf65344-c778-41ee-bacb-eb546bacfb9f a51006d0-146b-4b32-a2ce-7defbf0d7735 cf4abd9c-2cfa-4b5a-b1bd-e2b61a83fabd 50115496-7247-4e2c-857b-ec8680756bee].freeze
NFO_THRESHOLD = 5

WebMock.enable!
if ENV['LIVE'].to_s == '1'
  WebMock.allow_net_connect!
  MixinBot.configure do
    self.app_id = CONFIG['app_id']
    self.client_secret = CONFIG['client_secret']
    self.session_id = CONFIG['session_id']
    self.server_public_key = CONFIG['server_public_key']
    self.session_private_key = CONFIG['session_private_key']
  end
  PIN_CODE = CONFIG['pin'].to_s
  SPEND_KEY = CONFIG['spend_key'].to_s
else
  WebMock.disable_net_connect!(allow_localhost: true)
  OfflineConfig.apply!
  MixinBot.deprecator.behavior = :silence

  # Avoid real EventMachine / Blaze in default tests.
  MixinBot::API::Auth.prepend(Module.new do
    def authorization_data(_app_id, scope = ['PROFILE:READ'])
      { 'authorization_id' => SecureRandom.uuid, 'scopes' => scope }
    end
  end)

  # Blaze WebSocket entrypoint — keep default tests offline.
  MixinBot::API::Message.prepend(Module.new do
    def write_ws_message(params:, action: 'CREATE_MESSAGE')
      { 'id' => SecureRandom.uuid, 'action' => action, 'params' => params }
    end
  end)

  # Offline stubs omit UTXO + kernel data needed for real one-time-key signing.
  MixinBot::API::Transaction.prepend(Module.new do
    def sign_safe_transaction(**kwargs)
      raw = kwargs[:raw]
      txh = MixinBot.utils.decode_raw_transaction(raw)
      n = (txh[:inputs] || []).size
      txh[:signatures] = Array.new(n) { { 0 => '11' * 64 } }
      MixinBot.utils.encode_raw_transaction(txh)
    end
  end)

  MixinApiStubs.register!

  PIN_CODE = '123456'
  SPEND_KEY = OfflineConfig.spend_key_hex
end

require 'securerandom'

class Minitest::Test
  def setup
    ConversationStubState.reset! if defined?(ConversationStubState) && ENV['LIVE'].to_s != '1'
    super
  end
end
