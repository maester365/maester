function Get-MtPackBlocklist {
    <#
    .SYNOPSIS
    Returns the signed pack blocklist, fetched with a short timeout and cached for an hour (Maester Packs design, section 9.8).

    .DESCRIPTION
    The blocklist is a JSON envelope: KeyId, Signature (ECDSA P-256 over the payload bytes, SHA-256, base64)
    and Payload (base64 of a JSON object with Serial, IssuedAt, Expires and Entries). Only a list signed by a
    key in assets/MaesterPackTrust.json is used. A list with a lower serial than one this computer has seen
    is refused, so a mirror or a proxy cannot replay an old list, and an expired list counts as missing.

    When the list cannot be fetched, the newest cached list is used with a warning (fail open), unless
    PackPolicy.RequireFreshBlocklist is set, which makes it an error. While no blocklist key is configured in
    the trust file, nothing is fetched; RequireFresh still refuses to proceed without a list.

    Returns Available, Serial, Entries and Warning.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()] [switch] $RequireFresh,
        # Fetch again even when the cache is less than an hour old.
        [Parameter()] [switch] $Refresh
    )

    $Now = Get-Date -AsUTC
    $Result = { param($Available, $Serial, $Entries, $Warning, $Expires, $FetchedAt) [pscustomobject]@{ Available = $Available; Serial = $Serial; Entries = @($Entries); Warning = $Warning; Expires = $Expires; FetchedAt = $FetchedAt; ReadAt = $Now } }
    $CachedAt = if ($script:__MtPackBlocklist.Available) { $script:__MtPackBlocklist.FetchedAt } else { $script:__MtPackBlocklist.ReadAt }
    if ($CachedAt -and -not $Refresh -and ($Now - ([datetime]$CachedAt).ToUniversalTime()).TotalMinutes -ge 0 -and ($Now - ([datetime]$CachedAt).ToUniversalTime()).TotalMinutes -lt 60) {
        $Cached = $script:__MtPackBlocklist
        if (-not $Cached.Available -or ($Cached.Expires -and ([datetime]$Cached.Expires).ToUniversalTime() -gt $Now)) {
            if ($RequireFresh -and (-not $Cached.Available -or $Cached.Warning)) {
                throw 'A fresh pack blocklist is not available. PackPolicy.RequireFreshBlocklist is set, so no pack runs.'
            }
            return $Cached
        }
        # Expiry is signed content; the one-hour session cache must not extend it.
        $Refresh = $true
    }

    $Trust = Get-MtPackTrust
    $Keys = @($Trust.Blocklist.Keys | Where-Object { $_.KeyId -and $_.PublicKey })
    if ($Keys.Count -eq 0) {
        if ($RequireFresh) { throw 'No pack blocklist key is configured. PackPolicy.RequireFreshBlocklist is set, so no pack runs.' }
        Write-Verbose 'No pack blocklist key is configured yet, so there is no blocklist to check.'
        $script:__MtPackBlocklist = & $Result $false 0 @() $null
        return $script:__MtPackBlocklist
    }

    $CacheFile = (Get-MtPackHome).Blocklist
    $Cache = $null
    if (Test-Path -LiteralPath $CacheFile -PathType Leaf) {
        try { $Cache = Get-Content -LiteralPath $CacheFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $Cache = $null }
    }
    $Highest = if ($Cache -and $Cache.PSObject.Properties['HighestSerial']) { [long]$Cache.HighestSerial } else { 0 }
    $FetchedAt = if ($Cache -and $Cache.PSObject.Properties['FetchedAt']) { ([datetime]$Cache.FetchedAt).ToUniversalTime() } else { $null }
    $CachedList = $null
    if ($Cache -and $Cache.PSObject.Properties['Envelope']) {
        $CachedList = ConvertFrom-MtPackSignedList -Envelope $Cache.Envelope -Key $Keys
        if ($CachedList.Error) { $CachedList = $null }
    }
    $Now = Get-Date -AsUTC
    $Fresh = $FetchedAt -and ($Now - $FetchedAt).TotalMinutes -ge 0 -and ($Now - $FetchedAt).TotalMinutes -lt 60 -and
        $CachedList -and $CachedList.Payload.Expires -and ([datetime]$CachedList.Payload.Expires).ToUniversalTime() -gt $Now

    $Envelope = $null
    $FetchError = $null
    if (-not $Fresh -or $Refresh) {
        try {
            $Envelope = Invoke-RestMethod -Uri $Trust.Blocklist.Url -TimeoutSec 5 -Headers @{ 'User-Agent' = 'Maester' } -ErrorAction Stop
            if (-not $Envelope) { $FetchError = 'the blocklist response was empty' }
        } catch { $FetchError = $_.Exception.Message }
    }
    $List = $null
    if ($Envelope) {
        $List = ConvertFrom-MtPackSignedList -Envelope $Envelope -Key $Keys
        if ($List.Error) { $FetchError = $List.Error; $List = $null }
        elseif ([long]$List.Payload.Serial -lt $Highest) { $FetchError = "the blocklist has serial $($List.Payload.Serial), lower than $Highest seen before"; $List = $null }
        elseif (-not $List.Payload.Expires -or ([datetime]$List.Payload.Expires).ToUniversalTime() -le (Get-Date -AsUTC)) { $FetchError = 'the blocklist is expired'; $List = $null }
        else {
            $FetchedAt = Get-Date -AsUTC
            $Highest = [long]$List.Payload.Serial
            $Folder = Split-Path -Path $CacheFile -Parent
            if (-not (Test-Path -LiteralPath $Folder)) { $null = New-Item -Path $Folder -ItemType Directory -Force }
            [System.IO.File]::WriteAllText($CacheFile, ([ordered]@{ FetchedAt = $FetchedAt.ToString('o'); HighestSerial = $Highest; Envelope = $Envelope } | ConvertTo-Json -Depth 10))
        }
    }
    $Warning = $null
    if (-not $List -and $CachedList) {
        $List = $CachedList
        if ($FetchError) { $Warning = "The pack blocklist could not be refreshed ($FetchError); the cached list from $($Cache.FetchedAt) is used." }
    }
    if ($List -and (-not $List.Payload.Expires -or ([datetime]$List.Payload.Expires).ToUniversalTime() -le (Get-Date -AsUTC))) {
        $Warning = "The pack blocklist expired on $($List.Payload.Expires), so it was not used."
        $List = $null
    }
    if (-not $List) {
        $Warning = if ($FetchError) { "The pack blocklist could not be fetched ($FetchError), so installed packs were not checked against it." } elseif (-not $Warning) { 'No pack blocklist is available.' } else { $Warning }
        if ($RequireFresh) { throw "$Warning PackPolicy.RequireFreshBlocklist is set, so no pack runs." }
        $script:__MtPackBlocklist = & $Result $false 0 @() $Warning
        return $script:__MtPackBlocklist
    }
    if ($RequireFresh -and $Warning) { throw "$Warning PackPolicy.RequireFreshBlocklist is set, so no pack runs." }
    $script:__MtPackBlocklist = & $Result $true ([long]$List.Payload.Serial) @($List.Payload.Entries) $Warning $List.Payload.Expires $FetchedAt
    $script:__MtPackBlocklist
}

function ConvertFrom-MtPackSignedList {
    <#
    .SYNOPSIS
    Verifies a signed list envelope (KeyId, Signature, Payload) against the trusted keys and returns its payload, or Error.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Envelope,
        [Parameter(Mandatory)] [object[]] $Key
    )

    $key = $Key | Where-Object { $_.KeyId -eq $Envelope.KeyId } | Select-Object -First 1
    if (-not $key) { return [pscustomobject]@{ Error = "the blocklist is signed with an unknown key '$($Envelope.KeyId)'"; Payload = $null } }
    try {
        $payloadBytes = [System.Convert]::FromBase64String([string]$Envelope.Payload)
        $signature = [System.Convert]::FromBase64String([string]$Envelope.Signature)
        $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
        try {
            $read = 0
            $ecdsa.ImportSubjectPublicKeyInfo([System.Convert]::FromBase64String([string]$key.PublicKey), [ref] $read)
            $valid = $ecdsa.VerifyData($payloadBytes, $signature, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.DSASignatureFormat]::Rfc3279DerSequence) -or
                $ecdsa.VerifyData($payloadBytes, $signature, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)
        } finally { $ecdsa.Dispose() }
        if (-not $valid) { return [pscustomobject]@{ Error = 'the blocklist signature is not valid'; Payload = $null } }
        [pscustomobject]@{ Error = $null; Payload = ([System.Text.Encoding]::UTF8.GetString($payloadBytes) | ConvertFrom-Json -ErrorAction Stop) }
    } catch {
        [pscustomobject]@{ Error = "the blocklist could not be read: $($_.Exception.Message)"; Payload = $null }
    }
}

function Get-MtPackTrust {
    <#
    .SYNOPSIS
    Returns assets/MaesterPackTrust.json: where the blocklist is published and the public keys that sign it. Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    if (-not $script:__MtPackTrust) {
        $file = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterPackTrust.json'
        $script:__MtPackTrust = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    }
    $script:__MtPackTrust
}

function Find-MtPackBlock {
    <#
    .SYNOPSIS
    Returns the blocklist entry that applies to a pack version, or $null.

    .DESCRIPTION
    An entry matches by Digest, by RepositoryId or OwnerId, or by PackId with an optional Versions range.
    Any matching entry other than Warn stops the pack, regardless of order; otherwise the first Warn is returned.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Entry,
        [Parameter()] [string] $PackId,
        [Parameter()] [string] $Version,
        [Parameter()] [string] $Digest,
        [Parameter()] [long] $RepositoryId,
        [Parameter()] [long] $OwnerId
    )

    $Advisory = $null
    foreach ($E in $Entry) {
        $Has = { param($Name) $E.PSObject.Properties[$Name] -and $null -ne $E.$Name -and "$($E.$Name)" -ne '' }
        $EntryMatches = ((& $Has 'Digest') -and $Digest -and $E.Digest -eq $Digest) -or
            ((& $Has 'RepositoryId') -and $RepositoryId -and [long]$E.RepositoryId -eq $RepositoryId) -or
            ((& $Has 'OwnerId') -and $OwnerId -and [long]$E.OwnerId -eq $OwnerId)
        if ((& $Has 'PackId') -and $PackId -and $E.PackId -eq $PackId) {
            if (-not (& $Has 'Versions') -or ($Version -and (Test-MtVersionRange -Range ([string]$E.Versions) -Version $Version))) { $EntryMatches = $true }
        }
        if ($EntryMatches) {
            if ($E.Severity -ne 'Warn') { return $E }
            if (-not $Advisory) { $Advisory = $E }
        }
    }
    $Advisory
}
