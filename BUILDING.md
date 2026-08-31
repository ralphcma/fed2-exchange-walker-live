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

The result is `dist/exchange-walker-live-3.1.0-live.mpackage`.

The archive contains:

- `config.lua`
- `exchange-walker-live.xml`
- `f2ce-api.lua`
- `exchange-walker-live.lua`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`

## Offline tests

Using Lua 5.1:

```text
lua5.1 tests/exchange-walker-live-test.lua src/f2ce-api.lua src/exchange-walker-live.lua
```

Validate both Lua source files with `luac -p`. The exact package should be
extracted and the same test repeated against its two packaged Lua files.
