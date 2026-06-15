# lib/mixin_bot/client.rb

`MixinBot::Client` wraps Faraday with `https://{api_host}` base, JSON request/response middleware, `:retry` (max 2) on `Faraday::ConnectionFailed`/`Faraday::TimeoutError`, optional logger when `config.debug`.

Methods: `get(path, **kwargs)`, `post(path, *args, **kwargs)`, `fetch_get(path, query:)`, `fetch_post(path, body:)`, `fetch_post_array(path, array_body)`. Each signs a JWT via `MixinBot.utils.access_token` (exp_in 600, scp FULL) and parses into `MixinBot::Models::ApiEnvelope`. Errors flow through `ErrorMapper.raise_for!` for non-empty `result['error']`, or `raise_http_status_error!` for 401/403/429/5xx.