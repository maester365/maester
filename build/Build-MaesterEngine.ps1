<#
.SYNOPSIS
    Builds Maester.Engine.dll from src/Maester.Engine and copies it to powershell/lib.

.DESCRIPTION
    The engine DLL holds the [MaesterTest] and [MaesterParameter] attribute types and the
    scheduling core (Invoke-MtEngineRun). The built DLL is committed so that contributors who
    do not change the engine need no .NET SDK.

    Run this script after changing anything under src/Maester.Engine and commit the updated
    DLL with the source change. CI runs it with -Verify and fails when the committed DLL
    differs from a fresh build.

    Requires the .NET SDK pinned in src/global.json.

.PARAMETER Verify
    Builds to a temporary folder and compares the result with the committed DLL instead of
    replacing it. Throws when the bytes differ.

.EXAMPLE
    ./build/Build-MaesterEngine.ps1

    Rebuilds powershell/lib/Maester.Engine.dll.

.EXAMPLE
    ./build/Build-MaesterEngine.ps1 -Verify

    Fails if the committed DLL is not the build output of the committed source.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Build script output for the console')]
[CmdletBinding()]
param (
    [Parameter()]
    [switch] $Verify
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$project = Join-Path $repoRoot 'src/Maester.Engine/Maester.Engine.csproj'
$committed = Join-Path $repoRoot 'powershell/lib/Maester.Engine.dll'
$outDir = Join-Path ([System.IO.Path]::GetTempPath()) ("maester-engine-" + [guid]::NewGuid().ToString('n'))

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw 'The .NET SDK is required to build the engine. Install the version pinned in src/global.json.'
}

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

try {
    Push-Location (Split-Path $project)
    try {
        & dotnet build $project -c Release -o $outDir -nologo -v quiet
        if ($LASTEXITCODE -ne 0) { throw "dotnet build failed with exit code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }

    $built = Join-Path $outDir 'Maester.Engine.dll'
    if ($Verify) {
        if (-not (Test-Path $committed)) { throw "The committed engine DLL is missing: $committed" }
        $builtHash = (Get-FileHash -LiteralPath $built -Algorithm SHA256).Hash
        $committedHash = (Get-FileHash -LiteralPath $committed -Algorithm SHA256).Hash
        if ($builtHash -ne $committedHash) {
            throw "powershell/lib/Maester.Engine.dll does not match a build of src/Maester.Engine (committed $committedHash, built $builtHash). Run ./build/Build-MaesterEngine.ps1 and commit the DLL."
        }
        Write-Host "Engine DLL matches the source build ($builtHash)."
    } else {
        $null = New-Item -ItemType Directory -Path (Split-Path $committed) -Force
        Copy-Item -LiteralPath $built -Destination $committed -Force
        Write-Host "Built $committed ($((Get-Item $committed).Length) bytes, SHA256 $((Get-FileHash -LiteralPath $committed -Algorithm SHA256).Hash))."
    }
} finally {
    Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue
}
