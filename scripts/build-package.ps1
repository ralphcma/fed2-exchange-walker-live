# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 Exchange Walker Live contributors

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repositoryRoot 'src\exchange-walker-live.lua'
$packageDirectory = Join-Path $repositoryRoot 'package'
$distributionDirectory = Join-Path $repositoryRoot 'dist'
$destinationPath = Join-Path $distributionDirectory 'exchange-walker-live-3.0.0-live.mpackage'
$temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ('exchange-walker-live-' + [guid]::NewGuid().ToString('N') + '.zip')

New-Item -ItemType Directory -Path $distributionDirectory -Force | Out-Null

$archiveFiles = @(
    (Join-Path $packageDirectory 'config.lua'),
    (Join-Path $packageDirectory 'exchange-walker-live.xml'),
    $sourcePath,
    (Join-Path $repositoryRoot 'README.md'),
    (Join-Path $repositoryRoot 'LICENSE')
)

try {
    Compress-Archive -LiteralPath $archiveFiles -DestinationPath $temporaryPath -CompressionLevel Optimal
    Move-Item -LiteralPath $temporaryPath -Destination $destinationPath -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath
Write-Output "Built $destinationPath"
Write-Output "SHA256 $($hash.Hash)"
