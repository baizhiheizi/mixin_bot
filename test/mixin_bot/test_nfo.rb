# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestNfo < Minitest::Test
    def setup
    end

    def test_encode_mint_nft_memo
      collection = ''
      token_id = 204035246287023896153498043217692302767
      meta = {
        group: 'Bar',
        name: 'Foo',
        description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ',
        icon_url: 'https://mixin-images.zeromesh.net/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128',
        media_url: 'https://mixin-images.zeromesh.net/HvYGJsV5TGeZ-X9Ek3FEQohQZ3fE9LBEBGcOcn4c4BNHovP4fW4YB97Dg5LcXoQ1hUjMEgjbl1DPlKg1TW7kK6XP=s128',
        mime: 'image/png',
        hash: '1973a73d678690c5d004b6d6bfec65483749173617807ebf838a96900a3f6955'
      }

      hash = SHA3::Digest::SHA3_256.hexdigest meta.to_json

      result = 'TkZPAAEAAAAAAAAAAUPWHc3kE0UNgLgQHV6QM1cUPIwWGhiuLIsU_aEhb_99qIxBm10QAAAAAAAAAAAAAAAAAAAAABCZf8JRU9xKu5V5zW47G52vIN8k7X9uQpyzJLSJkRjT2KmX5tONE1oUM0E7o-TplLgq'

      memo = MixinBot.api.nft_memo collection, token_id, hash

      assert memo == result
    end

    def test_build_mint_memo
      nfo = MixinBot::Nfo.new(
        collection: '4d6d5171-de60-4dfa-bbca-8072b2df87d8',
        token: 69,
        extra: 'ff20cfcd4be747a165ec26f177b9b5ae6878eb9907434f4d936d0bef76064b4a'
      )

      memo = 'TkZPAAEAAAAAAAAAAUPWHc3kE0UNgLgQHV6QM1cUPIwWGhiuLIsU_aEhb_99qIxBm10QTW1Rcd5gTfq7yoByst-H2AFFIP8gz81L50ehZewm8Xe5ta5oeOuZB0NPTZNtC-92BktK'

      nfo.encode

      assert nfo.mint_memo == memo
    end

    def test_generate_token_id
      nfo = MixinBot::Nfo.new(
        collection: 'da0d22b0-b966-4f41-b26c-a3202644e226',
        token: 1
      )
      token_id = '53785273-1636-3b0b-a958-7646a5269d87'

      assert nfo.unique_token_id == token_id
    end

    def test_generate_token_id_from_null_collection_and_token
      nfo = MixinBot::Nfo.new(
        token: '83613129028534230817087350303625793902'
      )
      token_id = '9210779e-c9d3-3e2e-9233-909d728774a6'

      assert nfo.unique_token_id == token_id
    end

    def test_build_normal_memo
      extra = 'test'
      nfo = MixinBot::Nfo.new extra: extra.unpack1('H*')
      nfo.encode

      decoded = MixinBot::Nfo.new(hex: nfo.hex).decode

      assert [decoded.extra].pack('H*') == extra
    end

    def test_decode_nft_memo
      memo = 'TkZPAAEAAAAAAAAAAUPWHc3kE0UNgLgQHV6QM1cUPIwWGhiuLIsU_aEhb_99qIxBm10QTW1Rcd5gTfq7yoByst-H2AFFIP8gz81L50ehZewm8Xe5ta5oeOuZB0NPTZNtC-92BktK'
      extra = 'ff20cfcd4be747a165ec26f177b9b5ae6878eb9907434f4d936d0bef76064b4a'

      nfo = MixinBot::Nfo.new(memo:)

      nfo.decode

      assert nfo.extra == extra
    end

    def test_decode_nft_hex
      hex = '4e464f0001000000000000000143d61dcde413450d80b8101d5e903357143c8c161a18ae2c8b14fda1216fff7da88c419b5d100000000000000000000000000000000010a1acad756a3a4cb7ace88b750e2d82e620217fdcd1febd5f60a541ae3d91abd14bc00c3ea0004e767ed49b6cfec9c564a3'
      extra = '217fdcd1febd5f60a541ae3d91abd14bc00c3ea0004e767ed49b6cfec9c564a3'

      nfo = MixinBot::Nfo.new(hex:)

      nfo.decode

      assert nfo.extra == extra
    end
  end
end
