# Exchange Walker Live 3.2.1 Test Results

Date: 2026-09-01

## Source gates

- Lua 5.1 syntax: `f2ce-api.lua`, `exchange-walker-live.lua`, and the offline
  test harness passed `luac5.1 -p`.
- Offline source behavior: `RESULT 78 passed, 0 failed`.
- Git whitespace validation: passed.
- Mudlet package XML parsed with root `MudletPackage`.

## Exact package gates

Artifact: `dist/exchange-walker-live-3.2.1-live.mpackage`

SHA-256:

```text
98EA862D79C8223FAB0C1A5F0A34D27D8F565F56DE77AA0028B7910FE23004BD
```

- Required members: 7/7.
- Unexpected members: 0.
- Packaged Lua syntax: passed.
- Exact-package offline behavior: `RESULT 78 passed, 0 failed`.
- Packaged/source Lua hashes: 2/2 exact matches.
- XML, absolute-path, identity-leak, credential-string, and localhost checks:
  passed.

## Covered behavior

- Default OFF and zero mutation while OFF.
- F2CE dependency/version failure remains OFF.
- Complete exchange and production capture requirements.
- One-line rows and wraps before `Efficiency:`, after `Efficiency:`, or before `Net:`.
- Scoped replacement and restoration of F2CE's exchange parser.
- Exact parsed-row agreement with the server commodity summary.
- Bidirectional equality of normalized exchange and production commodity sets.
- Partial capture rejection with no plan and no mutation command.
- Existing negative-stock deficit acceptance remains covered.
- Supplementary replay of the reported Tempest exchange output: 67/67 rows parsed.
- Strict stock and spread field validation, while accepting finite negative
  current-stock deficits as valid live exchange data.
- Positive stock below and at the 10,000-ton policy boundary.
- Positive 40% and nonpositive 6% spread planning.
- Server-valid amount-first spread command generation.
- Explicit Apply, one outstanding command at a time, exact acknowledgement,
  mismatch stop, single-use plan, and no replay.
- Public Mux content registration, background preview updates, explicit
  display, active-tab preservation, and idempotent reload.
- Compact Preview instructions, bounded apply progress every 10 confirmations,
  exact final counts, and suppression of per-setting success spam.
- Reconnect reset to OFF and runtime-hook cleanup.
- Standalone operation without FedHaulerLive.

## Authorized live acceptance

- A new isolated Mudlet profile named `combined api testing` began with
  FedHaulerLive and Exchange Walker OFF.
- F2CE Tools 3.3.0-15829a0, Muxlet 2.3.0, Fed2 Module API 1.1.2,
  FedHaulerLive 1.12.0, and Exchange Walker 3.2.0-live loaded together.
- Live room, vitals, and ship GMCP were present. The shared API selected the
  `f2ce-3.3` adapter and reported no navigation owner or lease.
- Preview failed closed when the current planet was not owned. At an owned
  exchange, the complete exchange/production capture produced 89 reviewed
  changes. Explicit Apply sent every change once, matched every server
  confirmation, and completed 89/89 before returning Exchange Walker to OFF.
- The supplied F2CE map export (SHA-256
  `68807EA1AE9D37CBC382C3CE613AEADB44233A2E5DE3C4790FCE8B5DD5FF0888`)
  imported successfully with 5,761 rooms. F2CE rebuilt topology and synchronized
  the live room after a recoverable pre-import backup was created.
- The navigation API passed acquire/current-room-arrived/release with no
  residual owner or lease. The imported map resolves both exchange and
  shuttlepad flags in the current area, but both currently resolve to the same
  room ID, so a distinct movement round trip was correctly skipped.
- No futures trade, hauling workflow, credential capture, or forced eligibility
  was used during acceptance.
