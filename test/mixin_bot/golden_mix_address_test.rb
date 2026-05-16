# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class GoldenMixAddressTest < Minitest::Test
    FIXTURE = File.expand_path('../fixtures/golden/mix_address.json', __dir__)

    def setup
      @data = JSON.parse(File.read(FIXTURE))
    end

    def test_build_vectors_match_go_mix_test
      @data['build_vectors'].each do |v|
        expected = v['expected']
        members = v['members']
        threshold = v['threshold']

        from_utils = MixinBot.utils.build_mix_address(members:, threshold:)
        assert_equal expected, from_utils, v['id']

        from_class = MixAddress.new(members:, threshold:).address
        assert_equal expected, from_class, v['id']

        parsed = MixinBot.utils.parse_mix_address(expected)
        round = MixinBot.utils.build_mix_address(members: parsed[:members], threshold: parsed[:threshold])
        assert_equal expected, round, "#{v['id']} parse round-trip via utils"
      end
    end

    def test_wire_round_trip_strings_from_go
      @data['wire_round_trip'].each do |mix|
        ma = MixAddress.new(address: mix)
        assert_equal mix, ma.address

        h = MixinBot.utils.parse_mix_address(mix)
        assert_equal ma.threshold, h[:threshold]
        assert_equal (ma.uuid_members + ma.xin_members), h[:members]
        # Utils.build_mix_address sorts UUID/XIN member strings for a canonical encoding, so it
        # cannot round-trip every Go-generated MIX payload (e.g. duplicate UUID orderings).
      end
    end
  end
end
