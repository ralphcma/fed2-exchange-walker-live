# Exchange Walker Live 3.0

[![License: GPL v2](https://img.shields.io/badge/License-GPL_v2-blue.svg)](LICENSE)

An installable Mudlet package for controlled Federation 2 planet-exchange
stockpile management. Download the current package from
[`dist/exchange-walker-live-3.0.0-live.mpackage`](dist/exchange-walker-live-3.0.0-live.mpackage).

Exchange Walker Live is a Mudlet add-on for the Federation 2 public live
server. It reads the current planet's exchange and production reports, displays
a proposed stockpile plan, and applies that plan only after a separate explicit
command.

The add-on starts **OFF**. Loading it, enabling it, or clicking its toggle does
not change the game. `ew apply` is the only operation that sends stockpile
setting commands.

## Requirements

- Desktop Mudlet using the `fed2ce` profile.
- The current `f2ce-tools` package enabled in that profile.
- A live-server character who owns the current planet.
- The planet must have an exchange for the display and stockpile commands.
- GMCP must be active. Ownership and location are verified from GMCP before an
  apply operation.

Exchange Walker does not store an account name or password.

## Before installing

If Exchange Walker 2.0 was previously pasted into Mudlet or loaded with
`lua fetch_and_process_data()`, remove or disable that old script and restart
the `fed2ce` profile. Version 2.0 created temporary triggers that remain active
until the profile session ends. Leaving those triggers active can cause
duplicate captures or stockpile commands.

Do not install version 3.0 while an old Exchange Walker operation is running.

## Recommended persistent installation

1. Start Mudlet and open the `fed2ce` profile.
2. Open **Package Manager** from Mudlet's package/module controls.
3. Choose **Install**.
4. Select the downloaded package:

   ```text
   exchange-walker-live-3.0.0-live.mpackage
   ```

5. Confirm the package installation.
6. Restart or reload the `fed2ce` profile.
7. Confirm that Mudlet displays a message similar to:

   ```text
   [Exchange Walker] v3.0.0-live loaded for the public live server; default is OFF.
   ```

8. Confirm that the upper-right toggle reads:

   ```text
   Exchange Walker: OFF
   ```

The Package Manager method loads the add-on automatically on later profile
starts.

## Temporary installation

To test the add-on without installing the package, copy
`src/exchange-walker-live.lua` into the active Mudlet profile directory and
enter this in Mudlet's command line:

```lua
lua dofile(getMudletHomeDir() .. "/exchange-walker-live.lua")
```

The temporary installation must be loaded again after restarting the profile.

## Commands

| Command | Purpose |
|---|---|
| `ew help` | Display the command summary. |
| `ew on` | Enable capture and preview operations. Sends no game command. |
| `ew off` | Disable the walker, cancel capture, and cancel unsent commands. |
| `ew toggle` | Switch between ON and OFF. |
| `ew preview` | Read exchange and production data and construct a plan. |
| `ew apply` | Apply the latest reviewed, unexpired plan exactly once. |
| `ew cancel` | Cancel an active capture or commands not yet sent. |
| `ew status` | Display enabled, activity, and plan status. |

The original function name remains available for existing buttons:

```lua
lua fetch_and_process_data()
```

That function now performs a preview only. It does not apply the result.

To apply from a Mudlet Lua button or command:

```lua
lua exchange_walker_apply()
```

## ON/OFF toggle

The add-on creates a small button at the upper-right of Mudlet:

- Red `Exchange Walker: OFF`: no new capture or apply operation can start.
- Green `Exchange Walker: ON`: preview and explicit apply commands are
  available.

Clicking the button only changes the local enabled state. It never sends a
stockpile command.

The text commands `ew on` and `ew off` remain available if the button is hidden
by another Mudlet layout element.

## Safe operating procedure

1. Log into the public live server using the `fed2ce` Mudlet profile.
2. Make sure `f2ce-tools` is loaded and GMCP information is updating.
3. Move to a planet owned by the active character.
4. Enable Exchange Walker:

   ```text
   ew on
   ```

5. Request a preview:

   ```text
   ew preview
   ```

6. Wait for the complete preview table. The capture uses the live server's
   exchange completion marker and a rolling production-output completion
   timer supplied by F2CE Tools.
7. Review every old and proposed minimum/maximum value.
8. If the plan is correct, apply it within two minutes without moving:

   ```text
   ew apply
   ```

9. Read the server's confirmations. Commands are sent once and are never
   automatically retried.
10. Run another preview if any confirmation is missing or unexpected.
11. Disable the walker when finished:

   ```text
   ew off
   ```

For the first live use, stop after `ew preview` and inspect the table. Apply
only after confirming that the proposed policy matches the planet owner's
intent.

## Stockpile policy

For each commodity:

- Net production less than or equal to zero:
  - Minimum target: `0`
  - Maximum target: `0`
- Positive net production with current stock below 10,000 tons:
  - Minimum target: current stock, never below zero
  - Maximum target: minimum plus 1,000 tons
- Positive net production with current stock of at least 10,000 tons:
  - Existing minimum and maximum remain unchanged

No command is generated for a setting that already matches its target.

## Live commands used

Preview uses the F2CE Tools public-live parser and sends the display commands
for the current planet:

```text
display exchange
display production
```

Apply can send reviewed commands of these forms:

```text
set stockpile min <tons> <commodity>
set stockpile max <tons> <commodity>
```

There is no scheduled or recurring automation.

## Safety behavior

- The default state after loading is OFF.
- Apply requires GMCP to identify both the active character and planet owner.
- Apply is rejected if ownership does not match.
- A plan expires after two minutes.
- A room/location change invalidates the plan.
- A plan is marked applied before its first command is sent and cannot replay.
- OFF cancels capture and commands that have not yet been sent.
- Commands already delivered to the server cannot be recalled. After a cancel
  during apply, run a new preview to reconcile partial changes.
- Unexpected or missing server confirmation is not retried automatically.

## Troubleshooting

### `F2CE Tools planet-owner capture functions are unavailable`

Enable or update the installed `f2ce-tools` package, then restart the profile.
Exchange Walker intentionally uses its live-tested parser instead of installing
duplicate exchange triggers.

### `No live exchange rows were captured`

Confirm that:

- the active character owns the current planet;
- the planet has an exchange;
- F2CE Tools is enabled;
- the profile is connected to the public live server; and
- no other F2CE Tools planet-owner capture is active.

### Ownership is unknown or does not match

Wait for GMCP to populate, move or look to refresh room state, and run a new
preview. Exchange Walker will not bypass the ownership check.

### Preview expired

Run:

```text
ew preview
```

Review the new values before applying.

### Location changed

Return to the intended planet and create a new preview. An old plan is never
carried to another location.

### Duplicate output or duplicate commands

An older Exchange Walker script or trigger set is probably still active.
Immediately use `ew off`, stop issuing apply commands, restart the Mudlet
profile, remove the old version 2.0 script/triggers, and load only version 3.0.

### Toggle is not visible

Another GUI element may cover the upper-right label. Use:

```text
ew status
ew on
ew off
```

The add-on remains fully operable without clicking the button.

## Updating

1. Use `ew off`.
2. Uninstall the existing `exchange-walker-live` package through Package
   Manager.
3. Restart the profile to clear temporary aliases, triggers, and the old
   button.
4. Install the new `.mpackage`.
5. Restart the profile and verify the reported version.

## Uninstalling

1. Enter `ew off`.
2. Open Package Manager.
3. Uninstall `exchange-walker-live`.
4. Restart the `fed2ce` profile.
5. Optionally remove the standalone Lua and `.mpackage` files from the profile
   directory after keeping any desired backup.

## Verification information

Package version:

```text
3.0.0-live
```

The Lua source passes Lua 5.1 syntax validation. Offline tests verify that:

- loading and enabling send no commands;
- preview sends no stockpile mutation;
- explicit apply sends each planned setting once;
- an applied plan cannot replay; and
- OFF clears the plan and disables further actions.

No public live-server connection was used during development verification.

## Source provenance

Version 3.0 was updated from Exchange Walker 2.0 by Ersella of Serenity. It
retains the original stockpile policy while adapting capture to the current
public-server F2CE Tools interface and adding explicit preview/apply safety
controls.

## License

Exchange Walker Live is free software distributed under the GNU General Public
License version 2.0 only (`GPL-2.0-only`). See [LICENSE](LICENSE).
