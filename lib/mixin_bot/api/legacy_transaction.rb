# frozen_string_literal: true

module MixinBot
  class API
    module LegacyTransaction
      LEGACY_TX_VERSION = 0x04

      # use safe transaction protocol instead
      # kwargs:
      # {
      #   senders: [ uuid ],
      #   senders_threshold: integer,
      #   receivers: [ uuid ],
      #   receivers_threshold: integer,
      #   asset_id: uuid,
      #   amount: string / float,
      #   memo: string,
      # }
      RAW_TRANSACTION_ARGUMENTS = %i[utxos senders senders_threshold receivers receivers_threshold amount].freeze
      def build_raw_transaction(**kwargs)
        warn_legacy_mixin_api!('LegacyTransaction#build_raw_transaction')
        unless RAW_TRANSACTION_ARGUMENTS.all? do |param|
                 kwargs.keys.include? param
               end
          raise ArgumentError,
                "#{RAW_TRANSACTION_ARGUMENTS.join(', ')} are needed for build raw transaction"
        end

        senders             = kwargs[:senders]
        senders_threshold   = kwargs[:senders_threshold]
        receivers           = kwargs[:receivers]
        receivers_threshold = kwargs[:receivers_threshold]
        amount              = kwargs[:amount]
        asset_id            = kwargs[:asset_id]
        asset_mixin_id      = kwargs[:asset_mixin_id]
        utxos               = kwargs[:utxos]
        extra               = kwargs[:extra]
        access_token        = kwargs[:access_token]
        outputs             = kwargs[:outputs] || []
        hint                = kwargs[:hint]
        version             = kwargs[:version] || LEGACY_TX_VERSION

        raise 'access_token required!' if access_token.nil? && !senders.include?(config.app_id)

        amount = amount.to_d.round(8)
        input_amount = utxos.map(
          &lambda { |utxo|
            utxo['amount'].to_d
          }
        ).sum

        if input_amount < amount
          raise format(
            'not enough amount! %<input_amount>s < %<amount>s',
            input_amount:,
            amount:
          )
        end

        inputs = utxos.map(
          &lambda { |utx|
            {
              'hash' => utx['transaction_hash'],
              'index' => utx['output_index']
            }
          }
        )

        if outputs.empty?
          receivers_threshold = 1 if receivers.size == 1
          output0 = build_output(
            receivers:,
            index: 0,
            amount:,
            threshold: receivers_threshold,
            hint:
          )
          outputs.push output0

          if input_amount > amount
            output1 = build_output(
              receivers: senders,
              index: 1,
              amount: input_amount - amount,
              threshold: senders_threshold,
              hint:
            )
            outputs.push output1
          end
        end

        asset = asset_mixin_id || SHA3::Digest::SHA3_256.hexdigest(asset_id)
        {
          version:,
          asset:,
          inputs:,
          outputs:,
          extra:
        }
      end

      # use safe transaction protocol instead
      MULTISIG_TRANSACTION_ARGUMENTS = %i[asset_id receivers threshold amount].freeze
      def create_multisig_transaction(pin, **options)
        warn_legacy_mixin_api!('LegacyTransaction#create_multisig_transaction')
        unless MULTISIG_TRANSACTION_ARGUMENTS.all? do |param|
                 options.keys.include? param
               end
          raise ArgumentError,
                "#{MULTISIG_TRANSACTION_ARGUMENTS.join(', ')} are needed for create multisig transaction"
        end

        asset_id = options[:asset_id]
        receivers = options[:receivers].sort
        threshold = options[:threshold]
        amount = format('%.8f', options[:amount].to_d.to_r)
        memo = options[:memo]
        trace_id = options[:trace_id] || SecureRandom.uuid

        path = '/transactions'
        payload = {
          asset_id:,
          opponent_multisig: {
            receivers:,
            threshold:
          },
          amount:,
          trace_id:,
          memo:
        }

        payload.update(
          tip_or_legacy_pin_payload(pin, 'TIP:TRANSACTION:CREATE:', asset_id, receivers.join, threshold, amount, trace_id, memo)
        )

        client.post path, **payload
      end

      # use safe transaction protocol instead
      MAINNET_TRANSACTION_ARGUMENTS = %i[asset_id opponent_id amount].freeze
      def create_mainnet_transaction(pin, **options)
        warn_legacy_mixin_api!('LegacyTransaction#create_mainnet_transaction')
        unless MAINNET_TRANSACTION_ARGUMENTS.all? do |param|
                 options.keys.include? param
               end
          raise ArgumentError,
                "#{MAINNET_TRANSACTION_ARGUMENTS.join(', ')} are needed for create main net transactions"
        end

        asset_id = options[:asset_id]
        opponent_id = options[:opponent_id]
        amount = format('%.8f', options[:amount].to_d)
        memo = options[:memo]
        trace_id = options[:trace_id] || SecureRandom.uuid

        path = '/transactions'
        payload = {
          asset_id:,
          opponent_id:,
          amount:,
          trace_id:,
          memo:
        }

        payload.update(
          tip_or_legacy_pin_payload(pin, 'TIP:TRANSACTION:CREATE:', asset_id, opponent_id, amount, trace_id, memo)
        )

        client.post path, **payload
      end

      # use safe transaction protocol instead
      def transactions(**options)
        warn_legacy_mixin_api!('LegacyTransaction#transactions')
        path = '/external/transactions'
        params = {
          limit: options[:limit],
          offset: options[:offset],
          asset: options[:asset],
          destination: options[:destination],
          tag: options[:tag]
        }

        client.get path, **params
      end
    end
  end
end
