# Exchange Walker Live

Exchange Walker Live is an independently installable Mudlet package for
Federation 2 planet owners. It captures current or explicitly named remote
planet exchange/production reports through F2CE-Tools, calculates a configurable
stockpile/spread plan, and applies only exact reviewed changes. An optional
timer can manage a saved remote-planet list sequentially.

It does not require FedHaulerLive. Its only required runtime dependency is:

- F2CE-Tools 3.2.5 or a specifically validated compatible release.

Fed2 Module API 1.2.4+ is optional. When present, Exchange Walker uses its
shared leases, compatibility profiles, Mux registration, and typed command
gateway. When absent or not loaded yet, Exchange Walker uses its packaged
private F2CE adapter with the same OFF/preview/apply authorization rules.

## Safety model

- Load, reload, disconnect, and reconnect default to OFF.
- `ew on` only arms the package and sends no gameplay command.
- `ew preview [planet]` invokes F2CE's bounded exchange and production
  captures. A named target uses the remote display forms and does not navigate.
- Incomplete, malformed, mismatched, or stale captures create no plan.
- A local plan expires after 120 seconds and is discarded after a room change.
  A remote plan is bound to one validated target name and every mutation carries
  that same target; the game server remains authoritative for ownership.
- Every reviewed setting is passed through either the shared API's typed
  stockpile gateway or the packaged standalone adapter's exact allow-listed
  stockpile dispatcher. There is no arbitrary command-string interface.
- Each setting is sent once. The next setting waits for the exact server
  acknowledgement; a mismatch or six-second timeout stops the remaining queue.
- OFF and Cancel stop unsent work. A command already delivered cannot be recalled.
- Scheduled management is separately OFF by default. It requires saved targets
  and explicit `ew auto on`, rejects overlap, and turns OFF on its first failure.
- Excluded commodities are capture-validated but never planned or mutated.

## Configurable stockpile and spread policy

`net = production - consumption`

| Class | Default target minimum | Default target maximum | Default spread |
|---|---:|---:|---:|
| Deficit (`net < 0`) | `0` | `0` | `6%` |
| Breakeven (`net = 0`) | `0` | `0` | `6%` |
| Surplus below trigger | Current stock | Current stock + `1,000` | `40%` |
| Surplus at/above trigger | `10,000` | `20,000` | `40%` |

The deficit, breakeven, and surplus spreads are independent settings. Deficit
and breakeven minimum/maximum limits are independent settings. Surplus has an
editable growth buffer, reserve trigger, reserve minimum, and reserve maximum.
Only captured values that differ from the saved policy become actions.

## Muxlet display

The package registers Muxlet content ID `exchange_walker_live` through the
selected adapter and places it into the first existing empty pane from
`pane_15` through `pane_32`. The bounded placement never creates a pane/tab or
replaces content. If no safe pane exists, Exchange Walker remains registered
for manual selection from Muxlet's Content Library.

In Muxlet, open the Content Library for any pane/tab where you want the display
and choose **Exchange Walker**. Muxlet saves that user-owned placement. The
display contains lifecycle controls, Auto and Run Now, editable class policies,
the timer, remote targets, commodity exclusions, and the combined plan. Without
an active placed display, aliases and main-console notices remain available.

`ew display` retries the same safe placement without changing pane topology.

## Commands

| Command | Operation |
|---|---|
| `ew on` | Arm preview and explicit apply; sends nothing |
| `ew off` | Disable and cancel pending or unsent work |
| `ew preview` | Capture exchange + production and build a plan |
| `ew preview PLANET` | Build a remote target-qualified plan without navigation |
| `ew apply` | Apply the reviewed unexpired plan once |
| `ew cancel` | Cancel capture or unsent changes without disabling |
| `ew display` | Register/explain the Muxlet content placement |
| `ew settings` | Show saved timer, class policies, targets, and exclusions |
| `ew set NAME VALUE` | Change one numeric policy value |
| `ew target add/remove PLANET` | Edit the scheduled remote target list |
| `ew exclude add/remove COMMODITY` | Protect a commodity from all changes |
| `ew auto on/off/run/status` | Control the explicit scheduled remote manager |
| `ew status` | Show lifecycle and plan state |
| `ew api` | Show active adapter, F2CE, capture, and Mux capabilities |
| `ew help` | Show command help |

Numeric setting names are `interval`, `deficit-spread`, `deficit-min`,
`deficit-max`, `breakeven-spread`, `breakeven-min`, `breakeven-max`,
`surplus-spread`, `buffer`, `trigger`, `reserve-min`, and `reserve-max`.
Use `ew exclude list` or `ew target list` to review the saved lists; use the
corresponding `clear` command to empty one list.

Recommended flow:

```text
ew on
ew preview
```

Review all values, then without moving for a local plan:

```text
ew apply
```

For scheduled remote management, first save targets in the Mux pane or with
`ew target add PLANET`, then explicitly run:

```text
ew on
ew auto on
```

The first cycle starts immediately. Later cycles use the saved interval, which
defaults to 30 minutes. `ew auto off` stops the timer and unsent work.

## Compatibility boundary

`src/f2ce-api.lua` first selects the independently installed
`Fed2ModuleAPI/1.0` and registers Exchange Walker's authority policy. If that
optional package is unavailable, it loads `src/standalone-f2ce-api.lua`, a
private compatibility boundary limited to the capture, display, and exact
stockpile operations Exchange Walker uses. Policy code remains adapter-neutral.

The optional `ExchangeWalkerLive.public` contract remains
`ExchangeWalkerLive/1.0` and exposes status, lifecycle, preview/apply/cancel,
display registration, capabilities, and event subscription.

## Install

1. Install/enable Muxlet and F2CE-Tools 3.2.5.
2. Optionally install `fed2-module-api-1.2.4.mpackage` for shared integration.
3. Install `exchange-walker-live-3.3.2-live.mpackage`.
4. Confirm Exchange Walker reports OFF.
5. Run `ew api`. The display safely uses an empty pane at 15+ when available;
   otherwise place **Exchange Walker** from Muxlet Content Library.

Do not run multiple Exchange Walker versions simultaneously.

## Upgrade

Use `ew off`, uninstall the older Exchange Walker package, install the new
package, confirm OFF, review the migrated/default settings, and create a fresh
preview. Old plans and active timers are never restored.
After an optional Fed2 Module API upgrade, reload Exchange Walker to obtain a
fresh shared facade. Uninstalling the API causes the next Exchange Walker load
to select its private adapter automatically.

## Uninstall

Use `ew off`, then uninstall Exchange Walker. Runtime handlers, widgets, saved
settings, and any shared API client registration are released. Muxlet has no public
unregister-content function, so a catalog entry may remain until Muxlet rebuilds
its catalog; Exchange Walker does not mutate Muxlet private state to remove it.

## Known limitations

- Remote targets must be entered by the user; Exchange Walker does not discover
  owned planets or navigate between them.
- Remote ownership cannot be proven from current-room GMCP. Complete target-
  qualified captures and exact target-qualified commands are mandatory, and
  the server remains authoritative for rejecting non-owned targets.
- F2CE's production capture completes after a rolling silence timeout; Exchange
  Walker still requires an exact matching commodity set.
- The selected adapter installs a bounded wrapped-line parser only while this
  client owns an F2CE exchange capture, then restores the original parser.
- The standalone adapter cannot coordinate leases with other packages; avoid
  overlapping Exchange Walker captures with another F2CE capture consumer.
- No live-account command is issued by the offline test suite.

## License

Exchange Walker Live is licensed under GPL-2.0-only. See `LICENSE`.
