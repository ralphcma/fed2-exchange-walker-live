# Changelog

## 3.3.0-live — 2026-09-06

- Added remote exchange management using F2CE's target-qualified exchange and
  production captures plus the server's planet-qualified stockpile/spread
  commands. No navigation is required.
- Added separately configurable spread and stock-limit policies for deficit,
  breakeven, and surplus producers. Surplus growth buffer, reserve trigger,
  reserve minimum, and reserve maximum are all editable.
- Added persisted commodity exclusions. Excluded rows remain subject to
  complete-capture validation but can never generate a mutation command.
- Added an explicit-OFF scheduled controller with a configurable 30-minute
  default interval. It processes a saved remote target list sequentially,
  prevents overlapping cycles, and turns OFF on any capture, validation,
  authorization, acknowledgement, or timeout failure.
- Added editable policy, target, and exclusion fields to the Mux workspace
  content, plus Auto and Run Now controls.
- Added safe default placement into the first existing empty Mux pane from
  pane 15 through pane 32. Occupied panes are never replaced and no workspace
  pane or tab is created.
- Added settings-file migration from the prior positive/nonpositive spread
  schema and removal of package-owned settings on uninstall.
- Upgraded the shared dependency to Fed2 Module API 1.2.4 for typed remote
  production capture, remote mutations, and bounded safe Mux placement.
- Expanded offline coverage for independent production classes, configurable
  reserve policy, exclusions, remote commands, planet-specific confirmation,
  scheduled execution, and 30-minute timer behavior.

## 3.2.1-live — 2026-09-01

- Replaced one-console-line-per-setting apply confirmations with bounded
  progress summaries every 10 confirmed changes and one exact final count.
- Split Preview and Apply guidance into short, human-readable lines that do
  not rely on Markdown formatting inside Mudlet.
- Kept command ordering, exactly-once dispatch, acknowledgement matching,
  timeouts, fail-closed behavior, and explicit Preview/Apply authority
  unchanged.
- Live acceptance on F2CE Tools 3.3.0-15829a0 and Fed2 Module API 1.1.2
  validated a complete 89-change owned-exchange plan: every command was sent
  once and confirmed, then Exchange Walker returned to OFF.

## 3.2.0-live — 2026-09-01

- Replaced the package-local F2CE/Muxlet implementation with a thin consumer
  of independently installed Fed2 Module API 1.x.
- Routed every stockpile minimum, maximum, and spread mutation through the
  shared API's typed, capability-allow-listed command gateway.
- Retained explicit Preview/Apply, room/owner validation, acknowledgement
  sequencing, timeout, OFF/reconnect, and capture-completeness safety gates.
- Removed private Mux pane/tab mounting. Exchange Walker now uses only public
  content registration and leaves placement/activation to the user's workspace.
- Added regressions for shared dependency loading, zero transmissions while
  OFF, public-only Mux registration, capture/parser lease restoration, and exact
  typed setting dispatch.

## 3.1.4-live — 2026-08-31

- Corrected the 3.1.3 compatibility parser after live evidence showed that
  exchange rows can wrap before `Efficiency:` or between the efficiency value
  and `Net:`, rather than only after the `Efficiency:` label.
- Reconstructs a commodity record from its bounded continuation line before
  parsing, while refusing to consume the start of another commodity row.
- Retains exact summary-count and bidirectional commodity-set validation, so
  an unrecognized layout still creates no plan and sends no mutation command.
- Updated the regression fixture to cover the three observed layouts and
  replayed the reported 67-commodity Tempest capture at 67/67 offline.

## 3.1.3-live — 2026-08-31

- Fixed incomplete exchange plans caused by F2CE Tools 3.2.5 parsing only
  commodities whose `Efficiency` and `Net` fields wrapped onto two lines.
- Added an adapter-scoped exchange parser that accepts both the live one-line
  and wrapped two-line layouts, then restores F2CE's original parser as soon
  as Exchange Walker's capture completes or is cancelled.
- Required the parsed exchange row count to match the server's commodity
  summary count before a plan can exist.
- Required exchange and production captures to contain identical normalized
  commodity sets in both directions.
- Added mixed-wrap, parser-restoration, summary-mismatch, and asymmetric-set
  regressions.

## 3.1.2-live — 2026-08-31

- Restored automatic visible Stockpiles-tab placement after 3.1.1 made the
  registered content invisible unless manually added through Content Library.
- Added adapter-level restoration of the previously active F2CE tab, including
  when Muxlet internally selects a newly added tab.
- Kept preview output background-only; only explicit `ew display` activates the
  Stockpiles tab.
- Added regression coverage for Mux add-tab selection, active-tab restoration,
  visible placement, idempotent mount, and reload.

## 3.1.1-live — 2026-08-31

- Fixed valid negative current-stock deficits being rejected as incomplete
  exchange captures, including the reported NanoFabrics case.
- Retained fail-closed validation for configured minimum/maximum limits and
  added field-specific diagnostics with server range checks.
- Replaced automatic Mux tab creation with registration-only Content Library
  integration so Exchange Walker does not alter F2CE workspace composition or
  disturb Galaxy Navigator content.
- Preview now refreshes a placed Stockpiles display in the background without
  activating it; `ew display` raises only an existing user-placed target.
- Added regressions for negative current stock, invalid negative limits,
  registration-only Mux integration, active-tab preservation, and reload.

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
