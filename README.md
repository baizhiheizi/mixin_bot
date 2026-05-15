# MixinBot

[![CI](https://github.com/an-lee/mixin_bot/actions/workflows/ci.yml/badge.svg)](https://github.com/an-lee/mixin_bot/actions/workflows/ci.yml)

An API wrapper for [Mixin Network](https://developers.mixin.one/docs/api-overview)

## Installation

Add to gemfile, and `bundle install`

```ruby
gem 'mixin_bot'
```

Or

```shell
gem install mixin_bot
```

## Usage

### CLI

```bash
Commands:
  mixinbot api PATH -k, --keystore=KEYSTORE                                   # request PATH of Mixin API
  mixinbot decodetx TRANSACTION                                               # decode raw transaction
  mixinbot encrypt PIN -k, --keystore=KEYSTORE                                # encrypt PIN using private key
  mixinbot generatetrace HASH                                                 # generate trace ID from Tx hash
  mixinbot help [COMMAND]                                                     # Describe available commands or one specific command
  mixinbot nftmemo -c, --collection=COLLECTION -h, --hash=HASH -t, --token=N  # memo for mint NFT
  mixinbot unique UUIDS                                                       # generate unique UUID for two or more UUIDs
  mixinbot version                                                            # Distay MixinBot version

Options:
  -a, [--apihost=APIHOST]        # Specify mixin api host
                                 # Default: api.mixin.one
  -r, [--pretty], [--no-pretty]  # Print output in pretty
                                 # Default: true
```

Example:

```bash
$ mixinbot api /me -k ~/.mixinbot/keystore.json
```

### Initialize params

To use MixinBot api, you should set the keys first.

```ruby
MixinBot.configure do
  self.app_id = '25696f85-b7b4-4509-8c3f-2684a8fc4a2a'
  self.client_secret = 'd9dc58107bacde671...'
  self.session_id = '25696f85-b7b4-4509-8c3f-2684a8fc4a2a'
  self.server_public_key = 'b0pjBUKI0Vp9K+NspaL....'
  self.session_private_key = '...'
end
```

Supported Ruby: **3.2 through 4.x** (see the gemspec). Use **Bundler 2.5+** on Ruby 4. CI runs 3.2, 3.3, and 4.0.

### Call mixin apis

Then you can use MixinBot by call `MixinBot.api`, for example

```ruby
# get the bot profile
MixinBot.api.me

# get assets of the bot
MixinBot.api.assets

# transfer asset to somebody
MixinBot.api
  .create_transfer(
    '123456', # pin_code
    asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c', # the asset uuid to transfer
    opponent_id: '6ae1c7ae-1df1-498e-8f21-d48cb6d129b5', # receiver's mixin uuid
    amount: 0.00000001, # amount
    memo: 'test from MixinBot', # memo, 140 length at max
    trace_id: '0798327a-d499-416e-9b26-5cdc5b7d841e' # a uuid to trace transfer
)

# etc
```

### Connect Mixin Blaze

Your bot can receive/send messages from/to any users in Mixin Network, including all users in Mixin Messenger by connecting to Mixin Blaze.

With MixinBot, doing this is super easy.

```ruby
# run it in a EventMachine
EM.run {
  MixinBot.api.start_blaze_connect do
    # do something when the websocket connected
    def on_open(blaze, _event)
      p [Time.now.to_s, :on_open]

      # send the list_pending_message to receive messages
      blaze.send list_pending_message
    end

    # do something when receive message
    def on_message(blaze, event)
      raw = JSON.parse ws_message(event.data)
      p [Time.now.to_s, :on_message, raw&.[]('action')]

      blaze.send acknowledge_message_receipt(raw['data']['message_id']) unless raw&.[]('data')&.[]('message_id').nil?
    end

    # do something when websocket error
    def on_error(blaze, event)
      p [Time.now.to_s, :on_error]
    end

    # do something when websocket close
    def on_close(blaze, event)
      p [Time.now.to_s, :on_close, event.code, event.reason]
    end
  end
}
```

### Multiple Bot management

If you need to manage multiple mixin bot, you can config like this.

```ruby
bot1_api = MixinBot::API.new(
  app_id: '...',
  client_secret: '...',
  session_id: '...',
  server_public_key: '...',
  session_private_key: '...'
)

bot2_api = MixinBot::API.new(
  app_id: '...',
  client_secret: '...',
  session_id: '...',
  server_public_key: '...',
  session_private_key: '...'
)

bot1_api.me
bot2_api.me
```

## Documentation

Comprehensive RDoc documentation is available for the entire gem.

### Generate Documentation

```bash
# Using Rake
rake rdoc

# Or using RDoc directly
rdoc
```

Then open `doc/index.html` in your browser.

### Online Documentation

Documentation is also available online at [RubyDoc.info](https://www.rubydoc.info/gems/mixin_bot).

### Documentation Guides

- [DOCUMENTATION.md](DOCUMENTATION.md) - Complete documentation guide
- [RDOC_GUIDE.md](RDOC_GUIDE.md) - RDoc formatting and style guide

## More Example

See in the `Spec` files.

For WebSocket use case, see in `examples/blaze.rb`.

## Test

Clone the project:

```shell
git clone https://github.com/an-lee/mixin_bot
```

Update the spec config.yml to your own Mixin App(create in [developers.mixin.one](https://developers.mixin.one/dashboard)).

```shell
cd mixin_bot
mv spec/config.yml.example spec/config.yml
```

Run the test.

```shell
rake
```

## References

- [Mixin Network Document](https://developers.mixin.one/api)
- [mixin_client_demo (python)](https://github.com/myrual/mixin_client_demo)
- [mixin-node (nodejs)](https://github.com/virushuo/mixin-node)

## License

This project rocks and uses MIT-LICENSE.
