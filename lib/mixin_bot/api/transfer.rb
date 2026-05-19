# frozen_string_literal: true

module MixinBot
  class API
    ##
    # API methods for creating transfers using the Safe API.
    #
    # The Safe API is the recommended way to transfer assets on Mixin Network.
    # It provides better security, lower fees, and more flexibility than legacy transfers.
    #
    # == Transfer Process
    #
    # A Safe transfer involves several steps:
    # 1. Select UTXOs (unspent transaction outputs) as inputs
    # 2. Build the transaction with outputs
    # 3. Sign the transaction with spend key
    # 4. Submit the signed transaction
    #
    # This module handles all these steps automatically.
    #
    # == Usage
    #
    #   # Simple transfer to a single user
    #   api.create_transfer(
    #     members: 'user-uuid',
    #     asset_id: 'asset-uuid',
    #     amount: '0.01',
    #     memo: 'Payment'
    #   )
    #
    #   # Multisig transfer
    #   api.create_transfer(
    #     members: ['user1-uuid', 'user2-uuid', 'user3-uuid'],
    #     threshold: 2,
    #     asset_id: 'asset-uuid',
    #     amount: '0.01'
    #   )
    #
    module Transfer
      ##
      # Creates a Safe API transfer.
      #
      # This is the main method for sending assets on Mixin Network.
      # It handles the complete transfer process including UTXO selection,
      # transaction building, signing, and submission.
      #
      # @param kwargs [Hash] transfer options
      # @option kwargs [String, Array<String>] :members recipient user ID(s)
      # @option kwargs [Integer] :threshold multisig threshold (defaults to members.length)
      # @option kwargs [String] :asset_id the asset UUID to transfer
      # @option kwargs [String, Float] :amount the amount to transfer
      # @option kwargs [String] :trace_id unique trace ID (defaults to random UUID)
      # @option kwargs [String] :request_id alias for trace_id
      # @option kwargs [String] :memo transaction memo (max 140 characters)
      # @option kwargs [String] :spend_key spend private key (defaults to config.spend_key)
      # @option kwargs [Array<Hash>] :utxos specific UTXOs to use (optional, will auto-select if not provided)
      #
      # @return [Hash] the transfer result including transaction hash and status
      #
      # @raise [ArgumentError] if required parameters are missing or invalid
      # @raise [InsufficientBalanceError] if balance is insufficient
      #
      # @example Simple transfer
      #   result = api.create_transfer(
      #     members: '6ae1c7ae-1df1-498e-8f21-d48cb6d129b5',
      #     asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
      #     amount: '0.01',
      #     memo: 'Test payment'
      #   )
      #   puts result['snapshot_id']
      #
      # @example Multisig transfer (2-of-3)
      #   result = api.create_transfer(
      #     members: [
      #       '6ae1c7ae-1df1-498e-8f21-d48cb6d129b5',
      #       '8017d200-7870-4b82-b53f-74bae1d2dad7',
      #       'e8e8cd79-cd40-4796-8c54-3a13cfe50115'
      #     ],
      #     threshold: 2,
      #     asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
      #     amount: '0.01'
      #   )
      #
      def create_transfer(pin = nil, **kwargs)
        if pin.is_a?(String) && kwargs[:opponent_id].present?
          create_legacy_transfer(pin, **kwargs)
        else
          create_safe_transfer(**(pin.is_a?(Hash) ? pin : kwargs))
        end
      end

      def send_transaction(**kwargs)
        create_safe_transfer(**kwargs)
      end
      alias send_transfer_transaction send_transaction
      alias send_transaction_with_outputs send_transaction

      def send_transaction_until_sufficient(**kwargs)
        create_safe_transfer(**kwargs)
      end

      def send_transaction_with_change_outputs(**kwargs)
        create_safe_transfer(**kwargs)
      end
      alias send_transaction_with_utxos_and_change_outputs send_transaction_with_change_outputs

      def create_safe_transfer(**kwargs)
        utxos = kwargs[:utxos]
        raise ArgumentError, 'utxos must be array' if utxos.present? && !utxos.is_a?(Array)

        asset_id =
          if utxos.present?
            utxos.first['asset_id']
          else
            kwargs[:asset_id]
          end

        raise ArgumentError, 'utxos or asset_id required' if utxos.blank? && asset_id.blank?

        amount = kwargs[:amount]&.to_d
        raise ArgumentError, 'amount required' if amount.blank?

        members = [kwargs[:members]].flatten.compact
        raise ArgumentError, 'members required' if members.blank?

        threshold = kwargs[:threshold] || members.length
        request_id = kwargs[:request_id] || kwargs[:trace_id] || SecureRandom.uuid
        memo = kwargs[:memo] || ''

        # step 1: select inputs
        utxos ||= build_utxos(asset_id:, amount:)

        # step 2: build transaction
        tx = build_safe_transaction(
          utxos:,
          receivers: [{
            members:,
            threshold:,
            amount:
          }],
          extra: memo
        )
        raw = MixinBot.utils.encode_raw_transaction tx

        # step 3: verify transaction
        request = create_safe_transaction_request(request_id, raw)['data']

        # step 4: sign transaction
        spend_key = MixinBot.utils.decode_key(kwargs[:spend_key]) || config.spend_key
        signed_raw = MixinBot.api.sign_safe_transaction(
          raw:,
          utxos:,
          request: request[0],
          spend_key:
        )

        # step 5: submit transaction
        send_safe_transaction(
          request_id,
          signed_raw
        )
      end

      ##
      # Builds a UTXO set for a transfer.
      #
      # Selects unspent outputs (UTXOs) from the bot's wallet that sum up
      # to at least the requested amount. This is used internally by
      # create_safe_transfer but can be called directly if needed.
      #
      # The method:
      # - Fetches unspent outputs for the asset
      # - Sorts them by amount (smallest first)
      # - Selects outputs until the amount is reached
      # - Limits to 256 UTXOs maximum
      #
      # @param asset_id [String] the asset UUID
      # @param amount [String, Float, BigDecimal] the amount needed
      # @return [Array<Hash>] array of selected UTXOs
      #
      # @raise [InsufficientBalanceError] if balance is insufficient
      #
      # @example
      #   utxos = api.build_utxos(
      #     asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
      #     amount: '0.01'
      #   )
      #   puts "Selected #{utxos.length} UTXOs"
      #   puts "Total: #{utxos.sum { |u| u['amount'].to_d }}"
      #
      def build_utxos(asset_id:, amount:)
        amount = amount.to_d
        outputs = safe_outputs(state: 'unspent', asset: asset_id, limit: 500)['data'].sort_by { |o| o['amount'].to_d }

        utxos = []
        outputs.each do |output|
          break if utxos.size >= 256

          utxos << output
          break if utxos.sum { |o| o['amount'].to_d } >= amount
        end

        total_in = utxos.sum { |o| o['amount'].to_d }
        if total_in < amount
          raise MixinBot::UtxoInsufficientError.new(
            'insufficient utxo',
            total_input: total_in,
            total_output: amount,
            output_size: utxos.size
          )
        end

        utxos
      end
    end
  end
end
