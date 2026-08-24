# Building the Mudlet package

## Requirements

- PowerShell 5.1 or later
- Lua 5.1 or a compatible `luac` executable for optional syntax validation
- Mudlet for installation testing
- F2CE Tools for runtime exchange and production capture

## Build

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-package.ps1
```

The resulting archive is written to:

```text
dist/exchange-walker-live-3.0.0-live.mpackage
```

The `.mpackage` format is a ZIP archive containing:

- `config.lua`
- `exchange-walker-live.xml`
- `exchange-walker-live.lua`
- `README.md`
- `LICENSE`

## Offline behavior test

Using Lua 5.1:

```text
lua5.1 tests/exchange-walker-live-test.lua src/exchange-walker-live.lua
```

The test must finish with:

```text
Exchange Walker Live offline checks passed
```
