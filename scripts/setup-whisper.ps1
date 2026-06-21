param([string]$Release = "v1.9.1")

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $rootDir "app"
$toolsDir = Join-Path $appDir "tools"
$speechRoot = Join-Path $appDir "speech-backend\win"

function Enable-Tls12 {
    try {
        $tls12 = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor $tls12
    } catch {
        throw "TLS 1.2 could not be enabled: $($_.Exception.Message)"
    }
}

function Download-File {
    param([string]$Url, [string]$DestPath, [string]$Label)
    Write-Host "   >>  Downloading $Label..."
    Enable-Tls12
    $client = New-Object System.Net.WebClient
    $client.Headers.Add("User-Agent", "Local-AI-Image-Generator")
    try {
        $client.DownloadFile($Url, $DestPath)
    } finally {
        $client.Dispose()
    }
}

function Find-FirstFile {
    param([string]$Root, [string[]]$Names)
    foreach ($name in $Names) {
        $found = Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq $name } |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

New-Item -ItemType Directory -Force -Path $toolsDir, $speechRoot | Out-Null

$cliPath = Join-Path $speechRoot "whisper-cli.exe"
if (Test-Path $cliPath) {
    Write-Host "   OK  whisper.cpp speech backend already ready."
    exit 0
}

$asset = "whisper-bin-x64.zip"
$archive = Join-Path $toolsDir $asset
$extract = Join-Path $toolsDir "whisper-extract"
$url = "https://github.com/ggml-org/whisper.cpp/releases/download/$Release/$asset"

Remove-Item $archive, $extract -Recurse -Force -ErrorAction SilentlyContinue
Download-File -Url $url -DestPath $archive -Label "whisper.cpp speech backend ($Release)"

Write-Host "   >>  Extracting whisper.cpp speech backend..."
Expand-Archive -Path $archive -DestinationPath $extract -Force

$cli = Find-FirstFile -Root $extract -Names @("whisper-cli.exe", "main.exe")
$server = Find-FirstFile -Root $extract -Names @("whisper-server.exe", "server.exe")
if (-not $cli) {
    throw "whisper-cli.exe was not found after extracting $asset"
}

Get-ChildItem $extract -Recurse -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $speechRoot $_.Name) -Force
}
if ((Split-Path -Leaf $cli) -ine "whisper-cli.exe") {
    Copy-Item $cli $cliPath -Force
}
if ($server -and (Split-Path -Leaf $server) -ine "whisper-server.exe") {
    Copy-Item $server (Join-Path $speechRoot "whisper-server.exe") -Force
}

Remove-Item $archive, $extract -Recurse -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $cliPath)) {
    throw "whisper-cli.exe was not installed."
}
Write-Host "   OK  whisper.cpp speech backend installed."
