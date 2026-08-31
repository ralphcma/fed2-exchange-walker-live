# Exchange Walker Live

Exchange Walker Live is an independently installable Mudlet package for
Federation 2 planet owners. It uses F2CE Tools to capture the current planet's
exchange and production reports, calculates a stockpile and price-spread plan,
shows that plan in a dedicated F2CE Muxlet tab, and applies it only after an
explicit user command.

It does not navigate between planets, trade cargo, trade futures, or require
FedHaulerLive. Its only package dependency is F2CE Tools 3.2.5 or newer. Muxlet
is used when available through F2CE Tools; aliases and console output remain a
fallback if the workspace is not running.

## Safety model

- Fresh load, reload, disconnect, and reconnect default to OFF.
- `ew on` only arms the package and sends no gameplay command.
- `ew preview` sends `display exchange` and `display production` through F2CE
  Tools; it sends no mutation command.
- Incomplete or malformed exchange or production captures create no plan.
- A preview expires after 120 seconds and is discarded after a room change.
- `ew apply` requires matching GMCP planet ownership and room identity.
- Location and ownership are checked again before every mutation.
- Each command is sent once and the next command waits for the expected server
  acknowledgement. A mismatch or six-second timeout stops the remaining queue.
- OFF and Cancel stop unsent work. Commands already delivered cannot be recalled.

## Stockpile and spread policy

Net production is calculated as:

```text
net = production - consumption
```

| Condition | Target minimum | Target maximum | Target spread |
|---|---:|---:|---:|
| Net `<= 0` | `0` | `0` | `6%` |
| Net `> 0`, current stock `< 10,000` | Current stock | Current stock + `1,000` | `40%` |
| Net `> 0`, current stock `>= 10,000` | `10,000` | `20,000` | `40%` |

Only values that differ from the capture become actions. The live server syntax
for spread is amount-first, so a positive Alloys producer generates:

```text
set spread 40 Alloys
```

A nonpositive producer generates `set spread 6 <commodity>`.

## F2CE Muxlet display

The package registers content ID `exchange_walker_live` and automatically
places a selectable **Stockpiles** tab in F2CE's verified top-left `LeftTop`
pane beside **Who** and **Exchange**. The adapter restores whichever F2CE tab
was active before placement, even when Muxlet selects a newly created tab
internally. Preview updates Stockpiles in the background and does not activate it.

The display contains ON/OFF, Preview, Apply, Cancel, and Clear controls plus
narrow-pane cards combining `display exchange` and `display production`:

```text
Alloys            net +15 | stock 500
  prod/cons 20/5 | spread 20 -> 40
  limits 100/900 -> 500/1500
```

Use `ew display` to select the Stockpiles tab explicitly. If Muxlet is
unavailable, the same preview is printed to the main console and all aliases
continue to work.

## Commands

| Command | Operation |
|---|---|
| `ew on` | Arm preview and explicit apply; sends nothing |
| `ew off` | Disable and cancel capture or unsent changes |
| `ew preview` | Capture exchange and production and build a plan |
| `ew apply` | Apply the latest reviewed, unexpired plan once |
| `ew cancel` | Cancel capture or unsent changes without disabling |
| `ew display` | Open the F2CE Stockpiles Mux tab |
| `ew status` | Show lifecycle and plan state |
| `ew api` | Show adapter, F2CE, capture, and Mux capabilities |
| `ew help` | Show command help in the Stockpiles display |

Recommended flow:

```text
ew on
ew preview
```

Review every proposed limit and spread. If correct, without moving:

```text
ew apply
```

Run a new preview after any timeout, mismatch, cancellation, or partial apply.

## Compatibility boundary

`f2ce-api.lua` is the only module that binds to F2CE globals and Mux workspace
operations. Feature code uses the adapter contract
`ExchangeWalkerLive.F2CE/1.0`. F2CE upgrades should normally require changes in
that one adapter rather than in the policy engine.

An optional stable integration surface is available at:

```lua
ExchangeWalkerLive.public
```

Contract `ExchangeWalkerLive/1.0` exposes `status`, `on`, `off`, `preview`,
`apply`, `cancel`, `show`, `capabilities`, `subscribe`, and `unsubscribe`.
Events include `state.changed`, `plan.ready`, `preview.failed`,
`apply.started`, `apply.command_sent`, `apply.confirmed`, `apply.completed`, and
`apply.failed`. Third-party integration is optional; standalone operation does
not require another package.

The 3.0.x global functions remain as compatibility wrappers, including
`fetch_and_process_data()` as preview-only and `exchange_walker_apply()`.

## Install

1. Enable F2CE Tools 3.2.5 or newer in the Mudlet profile.
2. Open Mudlet Package Manager.
3. Install `exchange-walker-live-3.1.2-live.mpackage`.
4. Confirm the load message reports OFF.
5. Use `ew api` to confirm capture and Mux capabilities.

Do not run multiple Exchange Walker versions simultaneously.

## Upgrade

1. Use `ew off` and wait for any already-sent server response.
2. Uninstall the older `exchange-walker-live` package.
3. Install the new `.mpackage`.
4. Confirm it loads OFF and create a new preview. Old plans are never restored.

## Uninstall

1. Use `ew off`.
2. Uninstall `exchange-walker-live` in Mudlet Package Manager.
3. Restart the profile if an old Mux workspace tab remains cached.

## Known limitations

- The package manages only the current planet and contains no route walker.
- F2CE's production capture completes after a rolling output-silence timeout;
  Exchange Walker compensates by requiring a complete matching commodity set.
- F2CE's planet-owner capture service is global. The adapter refuses to reset a
  capture if its callback ownership has changed, but external callers that do
  not use the adapter cannot participate in its local lease.
- A command delivered before OFF or Cancel cannot be recalled.
- No live-account command is issued by the offline test suite.

## License

Exchange Walker Live is licensed under GPL-2.0-only. See `LICENSE`.
