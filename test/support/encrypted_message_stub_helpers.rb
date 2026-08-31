# frozen_string_literal: true

##
# Shared WebMock stubs and fixtures for encrypted-message pipeline tests.
# Requires the including class to have WebMock::API mixed in.
#
module EncryptedMessageStubHelpers
  def make_sessions(user_id)
    keypair = JOSE::JWA::Ed25519.keypair
    [
      {
        'user_id' => user_id,
        'session_id' => SecureRandom.uuid,
        'public_key' => Base64.urlsafe_encode64(JOSE::JWA::Ed25519.pk_to_curve25519(keypair[0]), padding: false)
      }
    ]
  end

  def make_sessions_with_keypair(user_id)
    keypair = JOSE::JWA::Ed25519.keypair
    sessions = [
      {
        'user_id' => user_id,
        'session_id' => SecureRandom.uuid,
        'public_key' => Base64.urlsafe_encode64(JOSE::JWA::Ed25519.pk_to_curve25519(keypair[0]), padding: false)
      }
    ]
    [sessions, keypair]
  end

  def stub_sessions_fetch(sessions_by_user)
    stub_request(:post, 'https://api.mixin.one/sessions/fetch').to_return do |request|
      requested = JSON.parse(request.body)
      list = requested.flat_map { |uid| sessions_by_user[uid] || [] }
      { status: 200, headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate({ 'data' => list, 'error' => nil }) }
    end
  end

  def stub_encrypted_messages(*state_sequences)
    captured = []
    stub_request(:post, 'https://api.mixin.one/encrypted_messages').to_return do |request|
      captured << JSON.parse(request.body)
      states = state_sequences.fetch(captured.size - 1)
      { status: 200, headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate({ 'data' => states, 'error' => nil }) }
    end
    captured
  end

  def response_entry(message_id, recipient_id, state)
    { 'type' => 'encrypted_message', 'message_id' => message_id,
      'recipient_id' => recipient_id, 'state' => state }
  end
end
