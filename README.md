# Exchange Walker Live

Exchange Walker Live is an independently installable Mudlet package for
Federation 2 planet owners. It captures the current planet's exchange and
production reports through F2CE-Tools, calculates a stockpile/spread plan, and
applies it only after an explicit user command.

It does not require FedHaulerLive. It does require:

- F2CE-Tools 3.2.5 or a specifically validated compatible release;
- Fed2 Module API 1.x, which centralizes the F2CE/Muxlet boundary and typed
  command dispatch for Exchange Walker and FedHaulerLive.

## Safety model

- Load, reload, disconnect, and reconnect default to OFF.
- `ew on` only arms the package and sends no gameplay command.
- `ew preview` invokes F2CE's bounded `display exchange` and
  `display production` captures; it sends no mutation command.
- Incomplete, malformed, mismatched, or stale captures create no plan.
- A plan expires after 120 seconds and is discarded after a room change.
- `ew apply` requires matching GMCP planet ownership and room identity.
- Location and ownership are rechecked before every setting change.
- Every reviewed setting is passed through the shared API's typed stockpile
  gateway. There is no arbitrary command-string interface.
- Each setting is sent once. The next setting waits for the exact server
  acknowledgement; a mismatch or six-second timeout stops the remaining queue.
- OFF and Cancel stop unsent work. A command already delivered cannot be recalled.

## Stockpile and spread policy

`net = production - consumption`

| Condition | Target minimum | Target maximum | Target spread |
|---|---:|---:|---:|
| Net `<= 0` | `0` | `0` | `6%` |
| Net `> 0`, stock `< 10,000` | Current stock | Current stock + `1,000` | `40%` |
| Net `> 0`, stock `>= 10,000` | `10,000` | `20,000` | `40%` |

Only captured values that differ from policy become reviewed actions.

## Muxlet display

The package registers public Muxlet content ID `exchange_walker_live`. It does
not inspect pane IDs, add or activate tabs, mutate the saved F2CE workspace, or
call private `Mux._applyContent()` functions.

In Muxlet, open the Content Library for any pane/tab where you want the display
and choose **Exchange Walker**. Muxlet saves that user-owned placement. The
display contains ON/OFF, Preview, Apply, Cancel, and Clear controls plus the
combined exchange/production plan. Without an active placed display, aliases
and main-console notices remain available.

`ew display` verifies/refreshes content registration and explains how to place
it; it does not force a pane or activate a tab.

## Commands

| Command | Operation |
|---|---|
| `ew on` | Arm preview and explicit apply; sends nothing |
| `ew off` | Disable and cancel pending or unsent work |
| `ew preview` | Capture exchange + production and build a plan |
| `ew apply` | Apply the reviewed unexpired plan once |
| `ew cancel` | Cancel capture or unsent changes without disabling |
| `ew display` | Register/explain the Muxlet content placement |
| `ew status` | Show lifecycle and plan state |
| `ew api` | Show shared API, F2CE, capture, and Mux capabilities |
| `ew help` | Show command help |

Recommended flow:

```text
ew on
ew preview
```

Review all values, then without moving:

```text
ew apply
```

## Compatibility boundary

`src/f2ce-api.lua` is a thin client registration and authority-policy shim.
The independently installed `Fed2ModuleAPI/1.0` owns F2CE bindings, owner-scoped
capture/parser restoration, dependency profiles, public Mux registration, and
typed command construction. F2CE/Muxlet compatibility changes should normally
be made once in Fed2 Module API rather than in Exchange Walker policy code.

The optional `ExchangeWalkerLive.public` contract remains
`ExchangeWalkerLive/1.0` and exposes status, lifecycle, preview/apply/cancel,
display registration, capabilities, and event subscription.

## Install

1. Install/enable Muxlet and F2CE-Tools 3.2.5.
2. Install `fed2-module-api-1.0.0.mpackage`.
3. Install `exchange-walker-live-3.2.0-live.mpackage`.
4. Confirm Exchange Walker reports OFF.
5. Run `ew api`, then place **Exchange Walker** from Muxlet Content Library.

Do not run multiple Exchange Walker versions simultaneously.

## Upgrade

Use `ew off`, uninstall the older Exchange Walker package, install the new
package, confirm OFF, and create a fresh preview. Old plans are never restored.
After a Fed2 Module API upgrade, reload Exchange Walker to obtain a fresh client
facade.

## Uninstall

Use `ew off`, then uninstall Exchange Walker. Runtime handlers, widgets, and the
shared API client registration are released. Muxlet has no public
unregister-content function, so a catalog entry may remain until Muxlet rebuilds
its catalog; Exchange Walker does not mutate Muxlet private state to remove it.

## Known limitations

- The package manages only the current planet and contains no route walker.
- F2CE's production capture completes after a rolling silence timeout; Exchange
  Walker still requires an exact matching commodity set.
- The shared API installs a bounded wrapped-line parser only while this client
  owns an F2CE exchange capture, then restores the original parser.
- External callers that bypass Fed2 Module API cannot participate in its leases.
- No live-account command is issued by the offline test suite.

## License

Exchange Walker Live is licensed under GPL-2.0-only. See `LICENSE`.
