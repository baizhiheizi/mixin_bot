# frozen_string_literal: true

require 'date'

module MixinBot
  class NodeCLI < Thor
    # https://github.com/Shopify/cli-ui
    UI = ::CLI::UI
    UI::StdoutRouter.enable

    desc 'listallnodes', 'List all mixin nodes'
    def listallnodes
      return unless ensure_mixin_command_exist

      o, e, _s = Open3.capture3('mixin -n 35.188.235.212:8239 listallnodes')
      log e unless e.empty?
      log o
    end

    desc 'mint', 'Mint from mint distributions'
    option :node, required: true, aliases: '-n', desc: 'node RPC address'
    option :batch, type: :numeric, required: true, aliases: '-b', desc: 'mint batch'
    option :view, type: :string, required: true, aliases: '-v', desc: 'view key'
    option :address, type: :string, required: true, aliases: '-d', desc: 'address'
    def mint
      c = (Date.today - Date.new(2019, 2, 28)).to_i + 1
      distributions = []
      UI::Spinner.spin('Listing mint distributions') do |spinner|
        o, _e, _s = Open3.capture3(
          'mixin',
          '-n',
          options[:node],
          'listmintdistributions',
          '-c',
          c.to_s
        )
        distributions = parse_mixin_cli_output(o)
        spinner.update_title "#{distributions.size} mint distributions listed"
      end

      tx = ''
      UI::Spinner.spin('Finding transaction') do |spinner|
        index = distributions.index(&->(d) { d[:batch] == options[:batch] })
        tx = distributions[index][:transaction]
        spinner.update_title "Transaction hash found: #{tx}"
      end

      UI::Spinner.spin('Fetching transaction') do |spinner|
        o, _e, _s = Open3.capture3(
          'mixin',
          '-n',
          options[:node],
          'gettransaction',
          '-x',
          tx
        )
        tx = parse_mixin_cli_output(o)
        spinner.update_title "#{tx[:outputs].size} transaction outputs found"
      end

      tx[:outputs].each_with_index do |output, index|
        address = ''
        UI::Spinner.spin("Checking output index: #{index}") do |spinner|
          o, _e, _s = Open3.capture3(
            'mixin',
            'decryptghostkey',
            '--key',
            output[:keys].first,
            '--mask',
            output[:mask],
            '--view',
            options[:view]
          )
          address = o.chomp
          spinner.update_title "Index #{index} Address: #{address}"
        end
        log "Found Utxo: #{index}" if address == options[:address]
      end
    end

    private

    def ensure_mixin_command_exist
      return true if command?('mixin')

      log UI.fmt '{{x}} `mixin` command is not valid!'
      log UI.fmt 'Please install mixin software and provide a executable `mixin` command'
    end

    def command?(name)
      `which #{name}`
      $CHILD_STATUS.success?
    end

    def parse_mixin_cli_output(output)
      JSON.parse(output, symbolize_names: true)
    rescue JSON::ParserError
      # Mixin node CLI historically prints Ruby hash literals.
      eval(output) # rubocop:disable Security/Eval
    end

    def log(obj)
      if options[:pretty]
        if obj.is_a? String
          puts obj
        else
          ap obj
        end
      else
        puts obj.inspect
      end
    end
  end
end
