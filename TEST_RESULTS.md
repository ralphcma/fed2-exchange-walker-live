# Exchange Walker Live 3.3.0 Test Results

Date: 2026-09-06

## Source gates

- Lua 5.1 syntax: `f2ce-api.lua`, `exchange-walker-live.lua`, and the offline
  test harness passed `luac5.1 -p`.
- Offline source behavior: `RESULT 136 passed, 0 failed`.
- Shared Fed2 Module API 1.2.4 behavior: passed.
- FedHaulerLive cross-package regression: `RESULT 155 passed, 0 failed`.
- Mudlet package XML parsed successfully.

## Exact package gates

Artifact: `dist/exchange-walker-live-3.3.0-live.mpackage`

SHA-256:

```text
d2d042b7b25a06fc1cfc333bbe74315d28cf382beb3d3d9858dce7fa39d2cc2d
```

- Required members: 7/7; unexpected members: 0.
- Packaged Lua syntax: passed.
- Exact-package behavior: `RESULT 136 passed, 0 failed`.
- Packaged/source Lua hashes: 2/2 exact matches.
- XML, absolute-path, identity, credential, connection-address, OneDrive, and
  localhost leak scans: passed.

Shared dependency artifact:
`D:/fedhaulerproject/outputs/fed2-module-api-1.2.4.mpackage`

SHA-256:

```text
86715528f0c586b286a4b27fab1153ea1da8a4939f8fcdea325938745783eef6
```

Its source and exact-package API suites both passed.

## Covered behavior

- Default OFF, reconnect OFF, explicit arming, and zero commands while OFF.
- Complete exchange/production capture and bidirectional commodity agreement.
- Wrapped F2CE exchange rows, finite negative current stock, and strict limits.
- Independent configurable deficit, breakeven, and surplus spread policies.
- Independent deficit/breakeven limits plus configurable surplus growth buffer,
  reserve trigger, reserve minimum, and reserve maximum.
- Commodity exclusions remain capture-validated but generate no actions.
- Current-room preview/apply retains room and GMCP owner validation.
- Remote target capture uses exact planet-qualified exchange and production
  requests without navigation.
- Every remote stockpile/spread mutation carries the exact reviewed planet.
- Wrong-planet or wrong-value confirmations cannot advance an apply queue.
- One outstanding mutation, exactly-once dispatch, six-second timeout, bounded
  progress, and single-use plans.
- Scheduled manager defaults OFF, requires explicit enable, blocks overlap,
  runs saved targets sequentially, and schedules the next cycle at the default
  30-minute interval only after complete success.
- Saved timer, policies, targets, and exclusions survive reload; package-owned
  settings are deleted on uninstall.
- Safe Mux placement preserves occupied pane 15 and selects existing empty pane
  16 in the fixture. It creates no pane or tab and remains idempotent on reload.
- Every editable Mux command-line field installs a no-op Enter action, so policy
  text can never be submitted as a game command.
- FedHaulerLive premium capture cleanup remains covered: `deleteFull()` removes
  captured rows plus prompts/blank lines, with `deleteLine()` only as the older
  Mudlet fallback.

## Live acceptance status

No gameplay connection or command was used for this 3.3.0 build. A local Mudlet
acceptance should install the exact API and Exchange Walker artifacts above,
begin OFF, verify safe Mux placement, preview one known owned remote planet,
compare the complete plan with live output, and only then explicitly Apply.
Scheduled automation should remain OFF until at least one manual remote preview
and apply has been reviewed successfully.
