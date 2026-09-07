# Building Exchange Walker Live

## Requirements

- PowerShell 5.1 or later.
- Lua 5.1 and `luac` for source validation.
- Mudlet for installation testing.
- F2CE Tools 3.2.5 or newer for runtime capture and Muxlet integration.

## Build

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-package.ps1
```

The result is `dist/exchange-walker-live-3.3.3-live.mpackage`.

The archive contains:

- `config.lua`
- `exchange-walker-live.xml`
- `f2ce-api.lua`
- `standalone-f2ce-api.lua`
- `exchange-walker-live.lua`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`

## Offline tests

Using Lua 5.1:

```text
lua5.1 tests/exchange-walker-live-test.lua src/f2ce-api.lua src/exchange-walker-live.lua
```

Validate all three Lua source files with `luac -p`. The build runs the behavior
suite twice—once with the optional shared API and once with only the packaged
standalone adapter—and repeats both modes against the exact package.
