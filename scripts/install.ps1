param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^(v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)|latest)$') {
    throw 'setup-jev: version must match vMAJOR.MINOR.PATCH or latest'
}

$repository = 'https://github.com/stefafafan/jev'
if ($Version -eq 'latest') {
    $response = Invoke-WebRequest -Uri "$repository/releases/latest" -MaximumRedirection 10
    $Version = $response.BaseResponse.RequestMessage.RequestUri.Segments[-1].TrimEnd('/')
    if ($Version -notmatch '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
        throw 'setup-jev: latest release did not resolve to a stable version'
    }
}

if ($env:RUNNER_OS -ne 'Windows') {
    throw "setup-jev: unsupported runner OS: $($env:RUNNER_OS ?? 'unknown')"
}

$architecture = switch ($env:RUNNER_ARCH) {
    'X64' { 'amd64' }
    'ARM64' { 'arm64' }
    default { throw "setup-jev: unsupported runner architecture: $($env:RUNNER_ARCH ?? 'unknown')" }
}

if (-not $env:RUNNER_TEMP) {
    throw 'setup-jev: RUNNER_TEMP is required'
}
if (-not $env:GITHUB_PATH) {
    throw 'setup-jev: GITHUB_PATH is required'
}
if (-not $env:GITHUB_OUTPUT) {
    throw 'setup-jev: GITHUB_OUTPUT is required'
}

$releaseVersion = $Version.Substring(1)
$name = "jev_${releaseVersion}_windows_${architecture}"
$archive = "$name.zip"
$downloadUrl = "$repository/releases/download/$Version"
$workDirectory = Join-Path $env:RUNNER_TEMP "setup-jev.$([guid]::NewGuid().ToString('N'))"

try {
    New-Item -ItemType Directory -Path $workDirectory | Out-Null
    $archivePath = Join-Path $workDirectory $archive
    $checksumsPath = Join-Path $workDirectory 'checksums.txt'
    Invoke-WebRequest -Uri "$downloadUrl/$archive" -OutFile $archivePath
    Invoke-WebRequest -Uri "$downloadUrl/checksums.txt" -OutFile $checksumsPath

    $escapedArchive = [regex]::Escape($archive)
    $checksumLines = @(Get-Content $checksumsPath | Where-Object {
        $_ -match "^([0-9a-fA-F]{64})\s+\*?$escapedArchive$"
    })
    if ($checksumLines.Count -ne 1) {
        throw "setup-jev: checksum is missing for $archive"
    }
    $expected = [regex]::Match($checksumLines[0], '^[0-9a-fA-F]{64}').Value
    $actual = (Get-FileHash -Algorithm SHA256 -Path $archivePath).Hash
    if ($actual -ne $expected) {
        throw "setup-jev: checksum verification failed for $archive"
    }

    Expand-Archive -Path $archivePath -DestinationPath $workDirectory
    $installDirectory = Join-Path $env:RUNNER_TEMP "setup-jev/$releaseVersion/windows-$architecture"
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
    $binary = Join-Path $installDirectory 'jev.exe'
    Copy-Item -Path (Join-Path $workDirectory "$name/jev.exe") -Destination $binary -Force

    $installedVersion = & $binary --version
    if ($installedVersion -ne "jev $releaseVersion") {
        throw "setup-jev: installed binary reported unexpected version: $installedVersion"
    }

    $installDirectory | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
    "version=$releaseVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    Write-Host "Installed jev $releaseVersion"
} finally {
    if (Test-Path $workDirectory) {
        Remove-Item -Path $workDirectory -Recurse -Force
    }
}
