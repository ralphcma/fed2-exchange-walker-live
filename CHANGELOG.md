# Changelog

## 3.1.0-live — 2026-08-31

- Extended positive-producer reserve policy: once current stock reaches 10,000
  tons, target minimum is 10,000 and target maximum is 20,000.
- Added price-spread planning: positive net producers target 40%; deficit and
  breakeven commodities target 6%.
- Added server-valid `set spread <amount> <commodity>` commands and strict
  acknowledgement matching.
- Added a dedicated F2CE Muxlet **Stockpiles** tab combining exchange and
  production data without replacing F2CE's Who or Exchange content.
- Added the `ExchangeWalkerLive.F2CE/1.0` compatibility facade and the optional
  `ExchangeWalkerLive/1.0` public integration surface.
- Made Mux optional at runtime while retaining F2CE Tools 3.2.5 as the only
  package dependency.
- Added strict numeric validation for captured current/min/max stock and spread.
- Changed Apply to acknowledgement-gated one-shot dispatch with a bounded
  timeout, per-command room/ownership revalidation, and no retry.
- Added load/reload/reconnect OFF enforcement and idempotent handler cleanup.
- Removed the collision-prone floating upper-right Geyser toggle.
- Expanded offline coverage for policy boundaries, spread commands, Mux mount,
  incomplete captures, acknowledgement sequencing, reload, and reconnect.

## 3.0.1-live — 2026-08-24

- Fixed EWL-2026-001 by rejecting incomplete production captures instead of
  interpreting missing commodity rows as zero production and consumption.
- Normalized commodity names when joining exchange and production captures.
- Added missing and malformed production-capture regression tests.

## 3.0.0-live — 2026-08-24

- Adapted exchange and production capture to current public F2CE Tools.
- Separated preview from explicit one-time apply.
- Added GMCP owner and room-identity checks, expiry, cancellation, aliases,
  documentation, tests, and portable Mudlet packaging.
