# Changelog

All notable technical changes to Exchange Walker Live are recorded here.

## 3.0.1-live - 2026-08-24

- Fixed EWL-2026-001 by rejecting incomplete production captures instead of
  interpreting missing commodity rows as zero production and consumption.
- Added normalized commodity matching plus duplicate, missing, malformed,
  non-numeric, NaN, and negative-value validation before plan construction.
- Made incomplete-capture handling fail closed: the preview is discarded,
  `EW.plan` remains empty, and `ew apply` has nothing to execute.
- Added regression coverage proving missing and malformed production rows send
  no commands and create no plan.
- Retained the 3.0.0 package in `dist/` for build history; it is superseded and
  must not be used for live apply operations.

## 3.0.0-live - 2026-08-24

- Adapted exchange and production capture to the current public Federation 2
  server output through the live-tested F2CE Tools parser.
- Added an upper-right Mudlet ON/OFF toggle, with OFF as the default state.
- Separated preview from mutation: `ew preview` never changes stockpiles and
  only `ew apply` sends reviewed settings.
- Added GMCP character ownership and room-identity validation before apply.
- Added two-minute plan expiration and invalidation after a room change.
- Made plans single-use by marking them applied before sending the first
  command.
- Added paced command delivery, confirmation observation, and cancellation of
  commands not yet sent.
- Preserved `fetch_and_process_data()` as a preview-only compatibility entry
  point for existing Mudlet buttons.
- Added offline behavior tests for default-OFF loading, non-mutating preview,
  one-time apply, replay prevention, and cancellation.
- Added an installable `.mpackage`, reproducible PowerShell build script,
  operator documentation, and GPL-2.0-only licensing.
