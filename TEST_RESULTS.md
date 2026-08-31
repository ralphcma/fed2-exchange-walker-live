# Exchange Walker Live 3.1.2 Test Results

Date: 2026-08-31

## Source gates

- Lua 5.1 syntax: `f2ce-api.lua`, `exchange-walker-live.lua`, and the offline
  test harness passed `luac5.1 -p`.
- Offline source behavior: `RESULT 68 passed, 0 failed`.
- Git whitespace validation: passed.
- Mudlet package XML parsed with root `MudletPackage`.

## Exact package gates

Artifact: `dist/exchange-walker-live-3.1.2-live.mpackage`

SHA-256:

```text
3A4A3A9D479172F4858C7C17226D7D58A267CD80D0344C2541857B3A72AE3D6D
```

- Required members: 7/7.
- Unexpected members: 0.
- Packaged Lua syntax: passed.
- Exact-package offline behavior: `RESULT 68 passed, 0 failed`.
- Packaged/source Lua hashes: 2/2 exact matches.
- XML, absolute-path, identity-leak, credential-string, and localhost checks:
  passed.

## Covered behavior

- Default OFF and zero mutation while OFF.
- F2CE dependency/version failure remains OFF.
- Complete exchange and production capture requirements.
- Strict stock and spread field validation, while accepting finite negative
  current-stock deficits as valid live exchange data.
- Positive stock below and at the 10,000-ton policy boundary.
- Positive 40% and nonpositive 6% spread planning.
- Server-valid amount-first spread command generation.
- Explicit Apply, one outstanding command at a time, exact acknowledgement,
  mismatch stop, single-use plan, and no replay.
- Automatic visible Stockpiles placement, restoration of the previously active
  F2CE tab, background preview updates, explicit display, and idempotent reload.
- Reconnect reset to OFF and runtime-hook cleanup.
- Standalone operation without FedHaulerLive.

## Not performed

No live-account login, server connection, navigation, or mutation command was
performed. Initial live acceptance must begin OFF, stop after Preview for human
review, and use explicit Apply only on a planet owned by the active character.
