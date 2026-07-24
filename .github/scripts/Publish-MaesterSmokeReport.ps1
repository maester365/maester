#Requires -Version 7.2

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string] $Repository,

    [Parameter(Mandatory)]
    [ValidatePattern('^smoke-[0-9]+-[0-9]+$')]
    [string] $Tag,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ReleaseName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ReleaseBody,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $AssetPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.-]+\.html$')]
    [string] $AssetName,

    [ValidateNotNullOrEmpty()]
    [string] $ApiBaseUrl = 'https://api.github.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$token = $env:MAESTER_REPORTS_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'MAESTER_REPORTS_TOKEN is required to publish the private report.'
}

$resolvedAsset = Resolve-Path -LiteralPath $AssetPath -ErrorAction Stop
if (-not (Test-Path -LiteralPath $resolvedAsset.Path -PathType Leaf)) {
    throw "The Maester HTML report '$AssetPath' does not exist."
}

$apiUri = [uri]$ApiBaseUrl
if ($apiUri.Scheme -ne 'https' -and -not $apiUri.IsLoopback) {
    throw 'ApiBaseUrl must use HTTPS unless it targets a loopback address.'
}
$apiBase = $ApiBaseUrl.TrimEnd('/')
$headers = @{
    Accept                 = 'application/vnd.github+json'
    Authorization          = "Bearer $token"
    'User-Agent'           = 'maester-action-smoke-test'
    'X-GitHub-Api-Version' = '2022-11-28'
}

function Get-HttpStatusCode {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    try {
        return [int]$ErrorRecord.Exception.Response.StatusCode
    } catch {
        return $null
    }
}

function Get-PrivateRelease {
    $escapedTag = [uri]::EscapeDataString($Tag)
    $releaseUri = "$apiBase/repos/$Repository/releases/tags/$escapedTag"

    try {
        return Invoke-RestMethod -Method Get -Uri $releaseUri -Headers $headers
    } catch {
        if ((Get-HttpStatusCode -ErrorRecord $_) -eq 404) {
            return $null
        }
        throw
    }
}

$release = Get-PrivateRelease
if ($null -eq $release) {
    $createUri = "$apiBase/repos/$Repository/releases"
    $createBody = @{
        tag_name               = $Tag
        target_commitish       = 'main'
        name                   = $ReleaseName
        body                   = $ReleaseBody
        draft                  = $false
        prerelease             = $true
        generate_release_notes = $false
        make_latest            = 'false'
    } | ConvertTo-Json

    try {
        $release = Invoke-RestMethod `
            -Method Post `
            -Uri $createUri `
            -Headers $headers `
            -ContentType 'application/json' `
            -Body $createBody
    } catch {
        if ((Get-HttpStatusCode -ErrorRecord $_) -ne 422) {
            throw
        }

        # All three matrix jobs may try to create the shared release. If
        # another operating system won that race, wait for the release to
        # become readable instead of failing the remaining report uploads.
        for ($attempt = 1; $attempt -le 10 -and $null -eq $release; $attempt++) {
            Start-Sleep -Milliseconds 500
            $release = Get-PrivateRelease
        }
        if ($null -eq $release) {
            throw "GitHub reported that release '$Tag' already exists, but it could not be retrieved."
        }
    }
}

$existingAssets = @(@($release.assets) | Where-Object name -EQ $AssetName)
if ($existingAssets.Count -gt 0) {
    throw "Release '$Tag' already contains an asset named '$AssetName'."
}

$uploadBase = [string]$release.upload_url -replace '\{\?name,label\}$', ''
$escapedAssetName = [uri]::EscapeDataString($AssetName)
$uploadUri = "${uploadBase}?name=$escapedAssetName"

[void](Invoke-RestMethod `
    -Method Post `
    -Uri $uploadUri `
    -Headers $headers `
    -ContentType 'text/html; charset=utf-8' `
    -InFile $resolvedAsset.Path)

Write-Output "Uploaded private report '$AssetName' to $Repository release '$Tag'."
