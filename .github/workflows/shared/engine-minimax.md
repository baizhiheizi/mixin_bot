---
# -1: disable AWF AI-credits budget. MiniMax-M3 is unknown to the built-in
# pricing table; a positive budget rejects it with unknown_model_ai_credits.
max-ai-credits: -1
max-daily-ai-credits: -1
engine:
  id: claude
  env:
    ANTHROPIC_API_KEY: ${{ secrets.MINIMAX_API_KEY }}
    ANTHROPIC_BASE_URL: "https://api.minimaxi.com/anthropic"
    ANTHROPIC_MODEL: "MiniMax-M3"
    API_TIMEOUT_MS: "3000000"
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1"
    CLAUDE_CODE_AUTO_COMPACT_WINDOW: "512000"
models:
  providers:
    anthropic:
      models:
        MiniMax-M3:
          cost:
            input: 1.20
            output: 4.80
            cache_read: 0.24
network:
  allowed:
    - defaults
    - api.minimaxi.com
---
