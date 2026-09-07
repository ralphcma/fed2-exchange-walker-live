# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 Exchange Walker Live contributors

[CmdletBinding()]
param(
    [string]$Lua = 'lua',
    [string]$Luac = 'luac',
    [string]$SharedApi = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageDirectory = Join-Path $repositoryRoot 'package'
$distributionDirectory = Join-Path $repositoryRoot 'dist'
$destinationPath = Join-Path $distributionDirectory 'exchange-walker-live-3.3.2-live.mpackage'
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('exchange-walker-live-' + [guid]::NewGuid().ToString('N'))
$verifyRoot = Join-Path $stageRoot 'verify'
$zipPath = Join-Path $stageRoot 'exchange-walker-live-3.3.2-live.zip'
if ([string]::IsNullOrWhiteSpace($SharedApi)) {
    $projectRoot = Split-Path -Parent (Split-Path -Parent $repositoryRoot)
    $SharedApi = Join-Path $projectRoot 'shared\fed2-module-api\src\fed2_module_api.lua'
}
if (-not (Test-Path -LiteralPath $SharedApi -PathType Leaf)) {
    throw "Fed2 Module API source not found: $SharedApi"
}

$sourcePaths = @(
    (Join-Path $repositoryRoot 'src\f2ce-api.lua'),
    (Join-Path $repositoryRoot 'src\standalone-f2ce-api.lua'),
    (Join-Path $repositoryRoot 'src\exchange-walker-live.lua')
)
$archiveFiles = @(
    (Join-Path $packageDirectory 'config.lua'),
    (Join-Path $packageDirectory 'exchange-walker-live.xml')
) + $sourcePaths + @(
    (Join-Path $repositoryRoot 'README.md'),
    (Join-Path $repositoryRoot 'CHANGELOG.md'),
    (Join-Path $repositoryRoot 'LICENSE')
)

foreach ($path in $sourcePaths + @((Join-Path $repositoryRoot 'tests\exchange-walker-live-test.lua'))) {
    & $Luac -p $path
    if ($LASTEXITCODE -ne 0) { throw "Lua syntax failed: $path" }
}
& $Lua (Join-Path $repositoryRoot 'tests\exchange-walker-live-test.lua') `
    $sourcePaths[0] $sourcePaths[2] $SharedApi
if ($LASTEXITCODE -ne 0) { throw 'source behavior tests failed' }
& $Lua (Join-Path $repositoryRoot 'tests\exchange-walker-live-test.lua') `
    $sourcePaths[0] $sourcePaths[2] $SharedApi `
    (Join-Path $stageRoot 'standalone-source-test-profile') $sourcePaths[1]
if ($LASTEXITCODE -ne 0) { throw 'standalone source behavior tests failed' }

New-Item -ItemType Directory -Path $distributionDirectory, $stageRoot, $verifyRoot -Force | Out-Null
try {
    Compress-Archive -LiteralPath $archiveFiles -DestinationPath $zipPath -CompressionLevel Optimal
    Expand-Archive -LiteralPath $zipPath -DestinationPath $verifyRoot -Force
    $required = @('config.lua', 'exchange-walker-live.xml', 'f2ce-api.lua', 'standalone-f2ce-api.lua',
        'exchange-walker-live.lua', 'README.md', 'CHANGELOG.md', 'LICENSE')
    $members = @(Get-ChildItem -LiteralPath $verifyRoot -File | ForEach-Object Name)
    foreach ($member in $required) {
        if ($members -notcontains $member) { throw "missing package member: $member" }
    }
    if ($members.Count -ne $required.Count) { throw 'package contains unexpected members' }
    [xml](Get-Content -LiteralPath (Join-Path $verifyRoot 'exchange-walker-live.xml') -Raw) | Out-Null
    foreach ($path in @((Join-Path $verifyRoot 'f2ce-api.lua'),
            (Join-Path $verifyRoot 'exchange-walker-live.lua'))) {
        & $Luac -p $path
        if ($LASTEXITCODE -ne 0) { throw "packaged Lua syntax failed: $path" }
    }
    & $Lua (Join-Path $repositoryRoot 'tests\exchange-walker-live-test.lua') `
        (Join-Path $verifyRoot 'f2ce-api.lua') `
        (Join-Path $verifyRoot 'exchange-walker-live.lua') $SharedApi `
        (Join-Path $stageRoot 'test-profile')
    if ($LASTEXITCODE -ne 0) { throw 'exact-package behavior tests failed' }
    & $Lua (Join-Path $repositoryRoot 'tests\exchange-walker-live-test.lua') `
        (Join-Path $verifyRoot 'f2ce-api.lua') `
        (Join-Path $verifyRoot 'exchange-walker-live.lua') $SharedApi `
        (Join-Path $stageRoot 'standalone-package-test-profile') `
        (Join-Path $verifyRoot 'standalone-f2ce-api.lua')
    if ($LASTEXITCODE -ne 0) { throw 'standalone exact-package behavior tests failed' }
    foreach ($source in $sourcePaths) {
        $packaged = Join-Path $verifyRoot (Split-Path -Leaf $source)
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne
            (Get-FileHash -Algorithm SHA256 -LiteralPath $packaged).Hash) {
            throw "packaged/source hash mismatch: $source"
        }
    }
    $forbidden = @('C:\\Users\\', '/home/', 'password\s*=\s*["'']',
        'play\.federation2\.com', '127\.0\.0\.1', 'OneDrive')
    foreach ($file in Get-ChildItem -LiteralPath $verifyRoot -File) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($pattern in $forbidden) {
            if ($content -match $pattern) { throw "portability/leak scan failed: $pattern in $($file.Name)" }
        }
    }
    Copy-Item -LiteralPath $zipPath -Destination $destinationPath -Force
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = (Resolve-Path -LiteralPath $stageRoot).Path
        $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        if (-not $resolvedStage.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "refusing to remove staging path outside TEMP: $resolvedStage"
        }
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath
Write-Output "Built $destinationPath"
Write-Output "SHA256 $($hash.Hash.ToLowerInvariant())"
Write-Output 'Validation: source/package Lua syntax and behavior, XML, members, hashes, portability, and leak scans passed.'
