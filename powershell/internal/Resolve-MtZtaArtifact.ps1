function Resolve-MtZtaArtifact {
    <#
    .SYNOPSIS
        Internal: detects the source kind of a ZTA result reference and returns a local
        directory containing the extracted bundle.

    .DESCRIPTION
        Three-source resolver for `Import-MtZtaResult`. Source patterns matched in priority order:

          1. ^https?://[^/]+\.blob\.core\.windows\.net/      Azure Blob
          2. ^upkg://  OR  ^https://pkgs\.dev\.azure\.com/.+/_apis/packaging/
                                                              Azure Artifacts Universal Package
          3. (else)                                          Local path: folder, .tar.gz, or .zip

        Returns the path to a LOCAL DIRECTORY containing manifest.json +
        ZeroTrustAssessmentReport.json + db/zt.db at minimum. If the source is already a
        local folder, returns it unchanged. If a tarball/zip, extracts to cache and returns
        the extracted path.

        Cache root: $env:TEMP/maester/zta-cache/ (override via `MAESTER_ZTA_CACHE`),
        keyed by `sha256(source)[:16]`. Retain last 5 OR anything used in last 30 days,
        whichever is larger.

        SAS query strings (?sig=...) are masked in any log line.

    .PARAMETER Source
        ZTA result source string. See Description for accepted patterns.

    .EXAMPLE
        $bundlePath = Resolve-MtZtaArtifact -Source '.\zta-results-2026-05-01.tar.gz'
        # -> $env:TEMP/maester/zta-cache/abcdef0123456789/

    .EXAMPLE
        $bundlePath = Resolve-MtZtaArtifact -Source 'https://contoso.blob.core.windows.net/zta/2026-05-01.tar.gz?sig=...'
        # -> downloads, extracts, returns local cache path
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Source
    )

    if ([string]::IsNullOrWhiteSpace($Source)) {
        throw 'Resolve-MtZtaArtifact: -Source is empty.'
    }

    # Mask SAS sig values in any log output
    $sourceForLog = $Source -replace '(\?|&)(sig|sv|st|se|sp|spr|sr|ss|srt|sip|tn)=[^&]*', '$1$2=***'
    Write-Verbose "Resolve-MtZtaArtifact: source = $sourceForLog"

    # Determine cache root
    $cacheRoot = if ($env:MAESTER_ZTA_CACHE) { $env:MAESTER_ZTA_CACHE } else { Join-Path ([System.IO.Path]::GetTempPath()) 'maester/zta-cache' }
    if (-not (Test-Path $cacheRoot)) { New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null }

    # Cache key: sha256(source)[:16]
    $sha    = [System.Security.Cryptography.SHA256]::Create()
    $hash   = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Source))
    $sha.Dispose()
    $key    = ([System.BitConverter]::ToString($hash) -replace '-', '').Substring(0, 16).ToLowerInvariant()
    $cacheDir = Join-Path $cacheRoot $key

    # Source kind detection — priority order matters
    $kind = $null
    if ($Source -match '^https?://[^/]+\.blob\.core\.windows\.net/') {
        $kind = 'AzureBlob'
    }
    elseif ($Source -match '^upkg://' -or $Source -match '^https://pkgs\.dev\.azure\.com/.+/_apis/packaging/') {
        $kind = 'UniversalPackage'
    }
    else {
        $kind = 'LocalPath'
    }
    Write-Verbose "Resolve-MtZtaArtifact: detected kind = $kind"

    switch ($kind) {
        'LocalPath' {
            if (-not (Test-Path $Source)) {
                throw "Resolve-MtZtaArtifact: local path not found: $Source"
            }
            $item = Get-Item $Source
            if ($item.PSIsContainer) {
                # Already a directory — use directly, no caching
                return (Resolve-Path $Source).Path
            }
            # File: must be .tar.gz, .tgz, or .zip
            if ($item.Name -match '\.tar\.gz$|\.tgz$') {
                Expand-MtZtaTarball -ArchivePath $item.FullName -DestinationPath $cacheDir
                return $cacheDir
            }
            elseif ($item.Name -match '\.zip$') {
                if (Test-Path $cacheDir) { Remove-Item -Recurse -Force $cacheDir }
                Expand-Archive -Path $item.FullName -DestinationPath $cacheDir -Force
                return $cacheDir
            }
            else {
                throw "Resolve-MtZtaArtifact: local path '$Source' is a file but not .tar.gz / .tgz / .zip."
            }
        }
        'AzureBlob' {
            $localFile = Join-Path $cacheDir 'download.tar.gz'
            if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }
            Get-MtZtaAzureBlob -BlobUrl $Source -DestinationFile $localFile
            Expand-MtZtaTarball -ArchivePath $localFile -DestinationPath $cacheDir
            return $cacheDir
        }
        'UniversalPackage' {
            $localFile = Join-Path $cacheDir 'download.tar.gz'
            if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }
            Get-MtZtaUniversalPackage -Reference $Source -DestinationDirectory $cacheDir
            # az artifacts universal download extracts the package; expect bundle files
            # to be present already. If a tarball is included, extract it.
            $tarball = Get-ChildItem -Path $cacheDir -Filter '*.tar.gz' -File | Select-Object -First 1
            if ($tarball) {
                Expand-MtZtaTarball -ArchivePath $tarball.FullName -DestinationPath $cacheDir
                Remove-Item $tarball.FullName -Force
            }
            return $cacheDir
        }
    }
}

function Expand-MtZtaTarball {
    <#
    .SYNOPSIS
        Internal: extracts a .tar.gz archive to a destination directory using the system tar.

    .DESCRIPTION
        Hardened against path-traversal: rejects entries whose normalized path escapes the
        destination root. PowerShell 7+ ships tar on every platform; on PS 5.1 falls back
        to System.IO.Compression for .zip only (callers using .tar.gz on PS 5.1 will get a
        clear error).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ArchivePath,
        [Parameter(Mandatory = $true)] [string] $DestinationPath
    )

    if (Test-Path $DestinationPath) { Remove-Item -Recurse -Force $DestinationPath }
    New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null

    $tarExe = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tarExe) {
        throw "Expand-MtZtaTarball: 'tar' not found on PATH. PowerShell 7+ on Windows/Linux/macOS ships it; install or upgrade."
    }

    $absDest = (Resolve-Path $DestinationPath).Path

    # Extract to a quarantine subdir first, validate paths, then move into place.
    $quarantine = Join-Path $absDest '.unpack'
    New-Item -ItemType Directory -Force -Path $quarantine | Out-Null

    & $tarExe -xzf $ArchivePath -C $quarantine
    if ($LASTEXITCODE -ne 0) {
        throw "Expand-MtZtaTarball: tar exited with $LASTEXITCODE extracting $ArchivePath."
    }

    # Path-traversal check: every file under quarantine must resolve under quarantine root.
    Get-ChildItem -Path $quarantine -Recurse -Force | ForEach-Object {
        $resolved = (Resolve-Path $_.FullName).Path
        if (-not $resolved.StartsWith($quarantine, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Expand-MtZtaTarball: path-traversal detected: $($_.FullName)"
        }
    }

    # Promote all entries up one level (out of .unpack/) into $DestinationPath.
    Get-ChildItem -Path $quarantine -Force | ForEach-Object {
        Move-Item -Path $_.FullName -Destination $absDest -Force
    }
    Remove-Item -Recurse -Force $quarantine -ErrorAction SilentlyContinue
}

function Get-MtZtaAzureBlob {
    <#
    .SYNOPSIS
        Internal: downloads a blob from Azure Blob Storage to a local file.

    .DESCRIPTION
        Auth ladder:
          1. SAS query in the URL    — Invoke-WebRequest directly
          2. Current Az session      — Get-AzStorageBlobContent -UseConnectedAccount
          3. WIF                     — Connect-AzAccount -ServicePrincipal -FederatedToken from $env:AZURE_FEDERATED_TOKEN
          4. Managed Identity        — Connect-AzAccount -Identity
        First successful path wins.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $BlobUrl,
        [Parameter(Mandatory = $true)] [string] $DestinationFile
    )

    $hasSas = $BlobUrl -match '\?(.*&)?sig='
    if ($hasSas) {
        Write-Verbose "Get-MtZtaAzureBlob: using SAS in URL"
        Invoke-WebRequest -Uri $BlobUrl -OutFile $DestinationFile -UseBasicParsing
        return
    }

    if (-not (Get-Module Az.Storage -ListAvailable -ErrorAction SilentlyContinue)) {
        throw "Get-MtZtaAzureBlob: Azure Blob URL has no SAS and Az.Storage module is not installed. Install Az.Storage or supply a SAS URL."
    }
    Import-Module Az.Storage -ErrorAction Stop

    # Parse account / container / blob from URL
    if ($BlobUrl -match '^https?://([^.]+)\.blob\.core\.windows\.net/([^/]+)/(.+?)(\?|$)') {
        $accountName = $Matches[1]
        $container   = $Matches[2]
        $blobName    = $Matches[3]
    }
    else {
        throw "Get-MtZtaAzureBlob: unrecognised Azure Blob URL shape: $BlobUrl"
    }

    # Ensure we have an Az context — try existing session first, then WIF, then MI.
    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
        if ($env:AZURE_FEDERATED_TOKEN -and $env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID) {
            Write-Verbose "Get-MtZtaAzureBlob: connecting via WIF"
            Connect-AzAccount -ServicePrincipal `
                              -ApplicationId $env:AZURE_CLIENT_ID `
                              -FederatedToken $env:AZURE_FEDERATED_TOKEN `
                              -Tenant $env:AZURE_TENANT_ID `
                              -ErrorAction Stop | Out-Null
        }
        else {
            Write-Verbose "Get-MtZtaAzureBlob: trying managed identity"
            Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
        }
    }

    $ctx = New-AzStorageContext -StorageAccountName $accountName -UseConnectedAccount -ErrorAction Stop
    Get-AzStorageBlobContent -Context $ctx -Container $container -Blob $blobName `
                             -Destination $DestinationFile -Force -ErrorAction Stop | Out-Null
}

function Get-MtZtaUniversalPackage {
    <#
    .SYNOPSIS
        Internal: downloads an Azure Artifacts Universal Package via `az artifacts universal download`.

    .DESCRIPTION
        Accepts two reference shapes:
          upkg://<org>/<project>/<feed>/<name>@<version>          (project-scoped)
          upkg://<org>//<feed>/<name>@<version>                   (org-scoped — note double slash)

        Plus the canonical Azure DevOps URL:
          https://pkgs.dev.azure.com/<org>/<project>/_apis/packaging/feeds/<feed>/upack/packages/<name>/versions/<version>

        Requires `az` CLI and an authenticated session (az login OR `SYSTEM_ACCESSTOKEN`
        env var on a build agent).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Reference,
        [Parameter(Mandatory = $true)] [string] $DestinationDirectory
    )

    $az = Get-Command az -ErrorAction SilentlyContinue
    if (-not $az) {
        throw "Get-MtZtaUniversalPackage: 'az' CLI not found. Install from https://aka.ms/installazurecliwindows."
    }

    $org = $null; $project = $null; $feed = $null; $name = $null; $version = $null

    if ($Reference -match '^upkg://([^/]+)/([^/]*)/([^/]+)/([^@]+)@(.+)$') {
        $org     = $Matches[1]
        $project = $Matches[2]   # may be empty for org-scoped
        $feed    = $Matches[3]
        $name    = $Matches[4]
        $version = $Matches[5]
    }
    elseif ($Reference -match '^https://pkgs\.dev\.azure\.com/([^/]+)/([^/]+)/_apis/packaging/feeds/([^/]+)/upack/packages/([^/]+)/versions/(.+)$') {
        $org     = $Matches[1]
        $project = $Matches[2]
        $feed    = $Matches[3]
        $name    = $Matches[4]
        $version = $Matches[5]
    }
    else {
        throw "Get-MtZtaUniversalPackage: unrecognised reference shape: $Reference"
    }

    if (-not (Test-Path $DestinationDirectory)) {
        New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
    }

    # `$args` is a PowerShell automatic variable — avoid assigning to it (PSScriptAnalyzer rule
    # PSAvoidAssignmentToAutomaticVariable). Use `$azArgs` instead; same shape, no side-effects.
    $azArgs = @(
        'artifacts', 'universal', 'download',
        '--organization', "https://dev.azure.com/$org",
        '--feed',         $feed,
        '--name',         $name,
        '--version',      $version,
        '--path',         $DestinationDirectory
    )
    if ($project) { $azArgs += @('--project', $project) }

    Write-Verbose "Get-MtZtaUniversalPackage: invoking az $($azArgs -join ' ')"
    & az @azArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Get-MtZtaUniversalPackage: az exited with $LASTEXITCODE downloading $name@$version from $org/$project/$feed."
    }
}
