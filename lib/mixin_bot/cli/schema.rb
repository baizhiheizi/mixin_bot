# frozen_string_literal: true

module MixinBot
  ##
  # Builds clispec-shaped schema documents for mixinbot.
  #
  module CLISchema
    MUTATING_COMMANDS = %w[
      transfer legacy-transfer safetransfer authcode updatetip saferegister pay
    ].freeze

    MUTATING_API_METHOD_PREFIXES = %w[
      create_ update_ delete_ send_ post_ authorize_ safe_register migrate_
      build_inscribe transfer_app upload_
    ].freeze

    COMMAND_DEFINITIONS = [
      {
        'name' => 'version',
        'description' => 'Display MixinBot gem version',
        'mutating' => false,
        'args' => [],
        'output_fields' => [
          { 'name' => 'version', 'type' => 'string' }
        ]
      },
      {
        'name' => 'schema',
        'description' => 'Emit machine-readable CLI schema (clispec-shaped)',
        'mutating' => false,
        'args' => [
          { 'name' => '--output', 'type' => 'string', 'required' => false,
            'enum' => %w[pretty json yaml], 'default' => nil }
        ],
        'output_fields' => [
          { 'name' => 'name', 'type' => 'string' },
          { 'name' => 'version', 'type' => 'string' },
          { 'name' => 'commands', 'type' => 'array' },
          { 'name' => 'errors', 'type' => 'array' }
        ]
      },
      {
        'name' => 'list',
        'description' => 'List callable MixinBot::API methods',
        'mutating' => false,
        'args' => [
          { 'name' => 'FILTER', 'type' => 'string', 'required' => false },
          { 'name' => '--limit', 'type' => 'integer', 'required' => false, 'default' => 100 },
          { 'name' => '--offset', 'type' => 'integer', 'required' => false, 'default' => 0 },
          { 'name' => '--fields', 'type' => 'string', 'required' => false,
            'description' => 'Comma-separated fields: name,owner' }
        ],
        'output_fields' => [
          { 'name' => 'items', 'type' => 'array' },
          { 'name' => 'total', 'type' => 'integer' },
          { 'name' => 'limit', 'type' => 'integer' },
          { 'name' => 'offset', 'type' => 'integer' }
        ]
      },
      {
        'name' => 'call',
        'description' => 'Invoke a MixinBot::API method with JSON keyword arguments',
        'mutating' => 'conditional',
        'mutating_note' => 'Mutating when METHOD matches write operations; use `mixinbot list` to inspect',
        'args' => [
          { 'name' => 'METHOD', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => false, 'aliases' => ['-k'] },
          { 'name' => '--data', 'type' => 'string', 'required' => false, 'default' => '{}', 'aliases' => ['-d'] },
          { 'name' => '--data-only', 'type' => 'boolean', 'required' => false, 'default' => false }
        ],
        'output_fields' => [
          { 'name' => 'data', 'type' => 'object | array | string' }
        ]
      },
      {
        'name' => 'api',
        'description' => 'Signed GET/POST request to a Mixin API path',
        'mutating' => 'conditional',
        'mutating_note' => 'Mutating when --method POST',
        'args' => [
          { 'name' => 'PATH', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] },
          { 'name' => '--method', 'type' => 'string', 'required' => false, 'default' => 'GET', 'aliases' => ['-m'] },
          { 'name' => '--data', 'type' => 'string', 'required' => false, 'default' => '{}', 'aliases' => ['-d'] },
          { 'name' => '--data-only', 'type' => 'boolean', 'required' => false, 'default' => true }
        ]
      },
      {
        'name' => 'transfer',
        'description' => 'Safe transfer to USER_ID',
        'mutating' => true,
        'args' => [
          { 'name' => 'USER_ID', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] },
          { 'name' => '--asset', 'type' => 'string', 'required' => true },
          { 'name' => '--amount', 'type' => 'string', 'required' => true },
          { 'name' => '--memo', 'type' => 'string', 'required' => false },
          { 'name' => '--trace', 'type' => 'string', 'required' => false },
          { 'name' => '--spend-key', 'type' => 'string', 'required' => false },
          { 'name' => '--dry-run', 'type' => 'boolean', 'required' => false, 'default' => false }
        ]
      },
      {
        'name' => 'legacy-transfer',
        'description' => 'Legacy POST /transfers (deprecated)',
        'mutating' => true,
        'args' => [
          { 'name' => 'USER_ID', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] },
          { 'name' => '--asset', 'type' => 'string', 'required' => true },
          { 'name' => '--amount', 'type' => 'number', 'required' => true }
        ]
      },
      {
        'name' => 'safetransfer',
        'description' => 'Alias for transfer (deprecated)',
        'mutating' => true,
        'args' => []
      },
      {
        'name' => 'authcode',
        'description' => 'OAuth authorization code',
        'mutating' => true,
        'args' => [
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] },
          { 'name' => '--app-id', 'type' => 'string', 'required' => true, 'aliases' => ['-c'] }
        ]
      },
      {
        'name' => 'saferegister',
        'description' => 'Register on SAFE network',
        'mutating' => true,
        'args' => [
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] },
          { 'name' => '--spend-key', 'type' => 'string', 'required' => true }
        ]
      },
      {
        'name' => 'pay',
        'description' => 'Generate Safe payment URL',
        'mutating' => false,
        'args' => [
          { 'name' => '--members', 'type' => 'array', 'required' => true },
          { 'name' => '--asset', 'type' => 'string', 'required' => true },
          { 'name' => '--amount', 'type' => 'string', 'required' => true }
        ]
      },
      {
        'name' => 'encrypt',
        'description' => 'Encrypt PIN using session keys',
        'mutating' => false,
        'args' => [
          { 'name' => 'PIN', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] }
        ]
      },
      {
        'name' => 'verifypin',
        'description' => 'Verify PIN',
        'mutating' => false,
        'args' => [
          { 'name' => 'PIN', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] }
        ]
      },
      {
        'name' => 'updatetip',
        'description' => 'Update TIP PIN',
        'mutating' => true,
        'args' => [
          { 'name' => 'PIN', 'type' => 'string', 'required' => true },
          { 'name' => '--keystore', 'type' => 'string', 'required' => true, 'aliases' => ['-k'] }
        ]
      },
      {
        'name' => 'utils',
        'description' => 'Utils subcommands (call, list)',
        'mutating' => false,
        'args' => []
      },
      {
        'name' => 'utils call',
        'description' => 'Invoke a MixinBot.utils method',
        'mutating' => false,
        'args' => [
          { 'name' => 'METHOD', 'type' => 'string', 'required' => true },
          { 'name' => '--data', 'type' => 'string', 'required' => false, 'default' => '{}', 'aliases' => ['-d'] }
        ]
      },
      {
        'name' => 'utils list',
        'description' => 'List callable MixinBot.utils methods',
        'mutating' => false,
        'args' => [
          { 'name' => 'FILTER', 'type' => 'string', 'required' => false },
          { 'name' => '--limit', 'type' => 'integer', 'required' => false, 'default' => 100 },
          { 'name' => '--offset', 'type' => 'integer', 'required' => false, 'default' => 0 },
          { 'name' => '--fields', 'type' => 'string', 'required' => false, 'default' => 'name' }
        ]
      },
      {
        'name' => 'unique',
        'description' => 'Deterministic UUID from two or more UUIDs',
        'mutating' => false,
        'args' => [{ 'name' => 'UUIDS', 'type' => 'array', 'required' => true }]
      },
      {
        'name' => 'generatetrace',
        'description' => 'Trace UUID from transaction hash',
        'mutating' => false,
        'args' => [{ 'name' => 'HASH', 'type' => 'string', 'required' => true }]
      },
      {
        'name' => 'decodetx',
        'description' => 'Decode raw transaction hex',
        'mutating' => false,
        'args' => [{ 'name' => 'TRANSACTION', 'type' => 'string', 'required' => true }]
      },
      {
        'name' => 'nftmemo',
        'description' => 'NFT mint memo',
        'mutating' => false,
        'args' => []
      },
      {
        'name' => 'rsa',
        'description' => 'Generate RSA key pair',
        'mutating' => false,
        'args' => []
      },
      {
        'name' => 'ed25519',
        'description' => 'Generate Ed25519 key pair',
        'mutating' => false,
        'args' => []
      }
    ].freeze

    module_function

    def build
      {
        'name' => 'mixinbot',
        'version' => MixinBot::VERSION,
        'license' => 'MIT',
        'commands' => commands_with_globals,
        'errors' => CLIErrors.schema_errors,
        'api_method_count' => CLIHelpers.api_callable_methods.size,
        'api_method_registry' => 'mixinbot list -o json'
      }
    end

    def commands_with_globals
      global_args = [
        { 'name' => '--apihost', 'type' => 'string', 'required' => false, 'default' => 'api.mixin.one',
          'aliases' => ['-a'] },
        { 'name' => '--output', 'type' => 'string', 'required' => false,
          'enum' => CLIOutput::OUTPUT_FORMATS, 'aliases' => ['-o'],
          'description' => 'Output format; defaults to pretty in TTY, json when piped' },
        { 'name' => '--pretty', 'type' => 'boolean', 'required' => false, 'default' => true,
          'aliases' => ['-r'], 'description' => 'Alias for --output pretty' }
      ]

      COMMAND_DEFINITIONS.map do |cmd|
        cmd.merge('global_args' => global_args)
      end
    end

    def mutating_api_method?(method_name)
      name = method_name.to_s
      MUTATING_API_METHOD_PREFIXES.any? { |prefix| name.start_with?(prefix) }
    end
  end
end
