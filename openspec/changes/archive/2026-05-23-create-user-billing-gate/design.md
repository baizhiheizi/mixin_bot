## Context

Mixin Safe apps use a prepaid billing model (`GET /safe/apps/:id/billing`). When `credit` is not greater than accumulated `cost` (users + resources), the app cannot use the API normally. Creating a network user via `POST /users` increases `cost.users` and is priced per user (first 10 free; thereafter ~$0.50 per user per Mixin billing docs).

Today, `MixinBot::API#create_user` posts directly with no preflight. `create_safe_user` calls `create_user` as its first step, so both paths are exposed. `app_billing` and `app_properties` already exist in `App` but are not used for guards. The Go SDK has no equivalent client-side gate—this is a Ruby SDK safety feature.

## Goals / Non-Goals

**Goals:**

- Block `create_user` by default when app credit lacks headroom for the next billed user.
- Provide `force: true` to skip the preflight and delegate to the server.
- Raise a dedicated `InsufficientAppBillingError` with actionable fields.
- Support CLI agents via `--force` on `create_user` calls and error kind `billing`.
- Cover behavior with offline WebMock tests.

**Non-Goals:**

- Gating `migrate_to_safe`, `safe_register`, or raw `mixinbot api POST /users`.
- Caching billing/properties responses.
- Auto-top-up or payment flows.
- Parity change in Go/Node SDKs.

## Decisions

### 1. Gate location: `create_user` only

**Decision:** Implement preflight in `App#ensure_app_billing_credit!`, invoked at the top of `User#create_user`.

**Rationale:** Single choke point; `create_safe_user` inherits automatically. `create_safe_user` forwards `force:` to `create_user` but does not duplicate the check.

**Alternative considered:** Gate `create_safe_user` separately — rejected; redundant and easy to drift.

### 2. Headroom formula

**Decision:**

```
credit > cost.users + cost.resources + increment
```

where `increment = BigDecimal(app_properties['price'] || '0')`.

**Rationale:** Ensures the app remains usable *after* the new user is billed. Strict `>` matches Mixin's "credit greater than cost" rule. `app_properties.price` reflects free-tier (`0`) vs paid tier without hardcoding `$0.50`.

**Alternative considered:** Compare `credit > cost` only — rejected; allows creation that immediately pushes app to lockout border.

### 3. Error type: `InsufficientAppBillingError`

**Decision:** New exception under `MixinBot::Error` with readers: `app_id`, `credit`, `cost`, `increment`.

**Rationale:** Distinct from wallet `InsufficientBalanceError` (API code 20117). Callers and CLI can branch on remediation ("top up app credit").

### 4. Preflight failure mode: fail closed

**Decision:** If billing or properties fetch fails, raise (do not proceed) unless `force: true`.

**Rationale:** Protects apps when preflight data is unavailable. `force` is the explicit operator override.

### 5. CLI `--force` scoping

**Decision:** Add `--force` to `mixinbot call`; inject `force: true` into kwargs **only when** the method is `create_user`. Merge order: parse `-d` first, then apply `--force` if not already set in kwargs (or: `--force` sets true, `-d '{"force":false}'` overrides — document that `-d` wins for explicit false).

**Rationale:** Avoids `ArgumentError: unknown keyword: force` on other API methods.

**Alternative considered:** Global `--force` merged into all calls — rejected; breaks unrelated methods.

### 6. CLI error kind: `billing`

**Decision:** Map `InsufficientAppBillingError` → `:billing` in `CLIErrors`, add to schema and `docs/agent/cli.md`.

**Rationale:** Agents can detect billing blocks without parsing message strings.

### 7. Decimal handling

**Decision:** Use `BigDecimal` for credit, cost components, and increment (consistent with transfer/transaction code).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Two extra GETs per `create_user` | Acceptable for a rare, mutating operation; skipped when `force: true` |
| `app_properties.price` semantics unverified live | Document assumption; adjust if live spike differs |
| Raw `mixinbot api POST /users` bypasses gate | Document as intentional escape hatch |
| Partial failure after forced create (orphan user) | Pre-existing; out of scope |
| `--force` only on `create_user` via `call` | Document; `create_safe_user` via `call` needs `-d '{"force":true}'` unless we extend allowlist later |

## Migration Plan

- **Release:** Minor version bump (additive `force:` kwarg, new error class; default behavior adds guard — behavior change but protective).
- **Rollback:** Remove guard; callers relying on preflight would lose protection.
- **Docs:** Note in YARD for `create_user` / `create_safe_user`; update `docs/agent/cli.md` and cookbook snippet for billing rescue.

## Open Questions

- _(none blocking)_ — Live validation of `app_properties.price` can happen post-ship if billing behavior differs in production.
