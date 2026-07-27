#!/usr/bin/env python3
"""Inject `defaultAiCreditsPricing` into the awf-config.json pipeline in lock files.

Why this exists
---------------
The agent runs Anthropic-compatible models through api.minimaxi.com (set
via `shared/engine-minimax.md`). The proxy (`gh-aw-firewall`) refuses calls
for any model whose pricing is unknown to its built-in table; MiniMax-M3 is
not in that table.

Two paths exist to supply per-model pricing:

* `models.providers.anthropic.models.<model>.cost` -> emits `apiProxy.providers`.
* `models.default-ai-credits-pricing` -> emits `apiProxy.defaultAiCreditsPricing`.

Both are blocked on gh-aw v0.83.1 (pinned by the action's setup-cli step):

* `providers` is silently dropped because the compiler requires AWF v0.27.42+
  (gh-aw v0.83.1 pins `DefaultFirewallVersion = v0.27.38`).
* `default-ai-credits-pricing` IS accepted by AWF v0.27.38 and by the schema,
  but gh-aw v0.83.1's CLI validator has a stale hardcoded list of allowed
  `models.*` fields (`allowed`, `blocked`, `providers`) and rejects the
  key at compile time.

The lock file is generated from the frontmatter, but `gh aw compile` cannot
emit either field for this combo, so the workaround lives directly in the
.lock.yml files: a `jq` step that injects `defaultAiCreditsPricing` into the
JSON config file after the printf and before AWF reads it.

When to re-run
--------------
After ANY of:

* `gh aw compile` (regenerates lock files from frontmatter; this patch is lost)
* `gh aw upgrade` (same)
* Manual edit to the printf string in the lock file

The pricing matches the per-model rates set in
`shared/engine-minimax.md`-derived `models.providers` blocks.

Idempotent: re-runs detect existing patches and skip them.
"""
import re
import sys

INJECT_BLOCK = (
    '          jq \'if .apiProxy then .apiProxy.defaultAiCreditsPricing={"input":3,"output":15,"cacheRead":0.3} else . end\' "${RUNNER_TEMP}/gh-aw/awf-config.json" > "${RUNNER_TEMP}/gh-aw/awf-config.json.tmp" && mv "${RUNNER_TEMP}/gh-aw/awf-config.json.tmp" "${RUNNER_TEMP}/gh-aw/awf-config.json"\n'
)

# Match the cp line that follows the printf in either the agent job
# (single-quoted JSON) or the detection job (double-quoted JSON).
PATTERN = re.compile(
    r'(\n          cp "\$\{RUNNER_TEMP\}/gh-aw/awf-config\.json" /tmp/gh-aw/awf-config\.json\n)',
)


def patch(lock_file: str) -> None:
    with open(lock_file) as f:
        content = f.read()
    # Count how many `cp ...` lines exist that aren't already followed by a jq patch.
    # Strategy: count `cp ...` occurrences and `defaultAiCreditsPricing` occurrences.
    cp_count = len(PATTERN.findall(content))
    patched_count = content.count('defaultAiCreditsPricing={"input":3,"output":15,"cacheRead":0.3}')
    if cp_count == 0:
        print(f"  x {lock_file}: no awf-config.json cp line found (does the lock file use AWF?)")
        return
    if patched_count >= cp_count:
        print(f"  = {lock_file}: already patched ({patched_count}/{cp_count} occurrences)")
        return
    new_content, count = PATTERN.subn(
        r'\n' + INJECT_BLOCK + r'\1',
        content,
        count=cp_count - patched_count,
    )
    if new_content == content:
        print(f"  x {lock_file}: pattern not found")
        sys.exit(1)
    with open(lock_file, 'w') as f:
        f.write(new_content)
    print(f"  + {lock_file}: injected {count} jq step(s) (now {patched_count + count}/{cp_count})")


if __name__ == '__main__':
    targets = sys.argv[1:] or [
        '.github/workflows/agentic-wiki-writer.lock.yml',
        '.github/workflows/dependabot-pr-bundler.lock.yml',
        '.github/workflows/doc-updater.lock.yml',
        '.github/workflows/repo-assist.lock.yml',
    ]
    for lock_file in targets:
        patch(lock_file)
