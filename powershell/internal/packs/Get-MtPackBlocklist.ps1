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
    the trust file, there is no list to check and nothing is fetched.

    Returns Available, Serial, Entries and Warning.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()] [switch] $RequireFresh,
        # Fetch again even when the cache is less than an hour old.
        [Parameter()] [switch] $Refresh
    )

    $result = { param($available, $serial, $entries, $warning) [pscustomobject]@{ Available = $available; Serial = $serial; Entries = @($entries); Warning = $warning; ReadAt = [datetime]::UtcNow } }
    if ($script:__MtPackBlocklist -and -not $Refresh -and ([datetime]::UtcNow - $script:__MtPackBlocklist.ReadAt).TotalMinutes -lt 60) { return $script:__MtPackBlocklist }

    $trust = Get-MtPackTrust
    $keys = @($trust.Blocklist.Keys | Where-Object { $_.KeyId -and $_.PublicKey })
    if ($keys.Count -eq 0) {
        Write-Verbose 'No pack blocklist key is configured yet, so there is no blocklist to check.'
        $script:__MtPackBlocklist = & $result $false 0 @() $null
        return $script:__MtPackBlocklist
    }

    $cacheFile = (Get-MtPackHome).Blocklist
    $cache = $null
    if (Test-Path -LiteralPath $cacheFile -PathType Leaf) {
        try { $cache = Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $cache = $null }
    }
    $highest = if ($cache -and $cache.PSObject.Properties['HighestSerial']) { [long]$cache.HighestSerial } else { 0 }
    $fresh = $cache -and $cache.PSObject.Properties['FetchedAt'] -and ([datetime]::UtcNow - ([datetime]$cache.FetchedAt).ToUniversalTime()).TotalMinutes -lt 60

    $envelope = $null
    $fetchError = $null
    if (-not $fresh -or $Refresh) {
        try {
            $envelope = Invoke-RestMethod -Uri $trust.Blocklist.Url -TimeoutSec 5 -Headers @{ 'User-Agent' = 'Maester' } -ErrorAction Stop
        } catch { $fetchError = $_.Exception.Message }
    }
    $list = $null
    if ($envelope) {
        $list = ConvertFrom-MtPackSignedList -Envelope $envelope -Key $keys
        if ($list.Error) { $fetchError = $list.Error; $list = $null }
        elseif ([long]$list.Payload.Serial -lt $highest) { $fetchError = "the blocklist has serial $($list.Payload.Serial), lower than $highest seen before"; $list = $null }
        else {
            $highest = [long]$list.Payload.Serial
            $folder = Split-Path -Path $cacheFile -Parent
            if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -Path $folder -ItemType Directory -Force }
            [System.IO.File]::WriteAllText($cacheFile, ([ordered]@{ FetchedAt = [datetime]::UtcNow.ToString('o'); HighestSerial = $highest; Envelope = $envelope } | ConvertTo-Json -Depth 10))
        }
    }
    $warning = $null
    if (-not $list -and $cache -and $cache.PSObject.Properties['Envelope']) {
        $list = ConvertFrom-MtPackSignedList -Envelope $cache.Envelope -Key $keys
        if ($list.Error) { $list = $null }
        elseif ($fetchError) { $warning = "The pack blocklist could not be refreshed ($fetchError); the cached list from $($cache.FetchedAt) is used." }
    }
    if ($list -and $list.Payload.Expires -and ([datetime]$list.Payload.Expires).ToUniversalTime() -lt [datetime]::UtcNow) {
        $warning = "The pack blocklist expired on $($list.Payload.Expires), so it was not used."
        $list = $null
    }
    if (-not $list) {
        $warning = if ($fetchError) { "The pack blocklist could not be fetched ($fetchError), so installed packs were not checked against it." } elseif (-not $warning) { 'No pack blocklist is available.' } else { $warning }
        if ($RequireFresh) { throw "$warning PackPolicy.RequireFreshBlocklist is set, so no pack runs." }
        $script:__MtPackBlocklist = & $result $false 0 @() $warning
        return $script:__MtPackBlocklist
    }
    if ($RequireFresh -and $warning) { throw "$warning PackPolicy.RequireFreshBlocklist is set, so no pack runs." }
    $script:__MtPackBlocklist = & $result $true ([long]$list.Payload.Serial) @($list.Payload.Entries) $warning
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
    Severity Block stops the pack; Warn lets it run with the advisory shown.
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

    foreach ($e in $Entry) {
        $has = { param($name) $e.PSObject.Properties[$name] -and $null -ne $e.$name -and "$($e.$name)" -ne '' }
        if ((& $has 'Digest') -and $Digest -and $e.Digest -eq $Digest) { return $e }
        if ((& $has 'RepositoryId') -and $RepositoryId -and [long]$e.RepositoryId -eq $RepositoryId) { return $e }
        if ((& $has 'OwnerId') -and $OwnerId -and [long]$e.OwnerId -eq $OwnerId) { return $e }
        if ((& $has 'PackId') -and $PackId -and $e.PackId -eq $PackId) {
            if (-not (& $has 'Versions') -or ($Version -and (Test-MtVersionRange -Range ([string]$e.Versions) -Version $Version))) { return $e }
        }
    }
    $null
}
