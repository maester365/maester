function Invoke-MtPackInstall {
    <#
    .SYNOPSIS
    Installs one pack and the packs it requires into a lock (Maester Packs design, sections 4.2 and 5).

    .DESCRIPTION
    The work behind Install-MtPack and Update-MtPack. For the pack and each pack it requires, in that order
    of need (required packs first):

    1. Fetch and validate it (Get-MtPackCandidate). Errors stop the install; nothing has run.
    2. Refuse test IDs that clash with another installed pack.
    3. Check the pack policy and the blocklist.
    4. Save and pin its Gallery modules (Save-MtPackModule). A module the user installed, used under
       AllowExternalEnvironments, makes the pack High risk.
    5. Ask (Show-MtPackApproval).
    6. Copy it into the store under its digest, read-only, and check the digest of the copy.
    7. Write its entry, and its modules, into -Lock.

    A required pack that the lock already has at a version in range is kept as it is. Cycles are refused.
    With -SkipUnchanged (Update-MtPack), a pack whose files have the digest of -Previous is not approved or
    installed again: -Previous is returned as it is.
    Returns the lock entry of the pack that was asked for.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Install progress is written for a person at the console.')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter()] [string] $Version,
        [Parameter(Mandatory)] [pscustomobject] $Lock,
        [Parameter(Mandatory)] [pscustomobject] $Policy,
        [Parameter()] [ValidateSet('Low', 'Medium', 'High')] [string] $AcceptRisk = 'Low',
        [Parameter()] [switch] $IncludeRecent,
        [Parameter()] [switch] $Force,
        [Parameter()] [switch] $NonInteractive,
        # The entry this install replaces (Update-MtPack).
        [Parameter()] [AllowNull()] [object] $Previous,
        # The pack IDs being installed above this one, to refuse cycles.
        [Parameter()] [string[]] $Stack = @(),
        # Return -Previous when the fetched files have its digest, without asking again.
        [Parameter()] [switch] $SkipUnchanged
    )

    $candidate = Get-MtPackCandidate -Source $Source -Version $Version -IncludeRecent:$IncludeRecent -CooldownHours $Policy.CooldownHours
    try {
        if ($candidate.Errors.Count -gt 0) {
            $list = @($candidate.Errors | Select-Object -First 15 | ForEach-Object { "  $($_.Code): $(ConvertTo-MtPackSafeText $_.Message -MaxLength 300)" }) -join [Environment]::NewLine
            $more = if ($candidate.Errors.Count -gt 15) { "$([Environment]::NewLine)  and $($candidate.Errors.Count - 15) more; run Test-MtPack to see them all." } else { '' }
            throw "The pack from '$Source' was not installed because it has $($candidate.Errors.Count) problem(s):$([Environment]::NewLine)$list$more"
        }
        foreach ($w in $candidate.Warnings) { Write-Warning (ConvertTo-MtPackSafeText $w -MaxLength 300) }
        $id = $candidate.Id
        if ($SkipUnchanged -and $Previous -and $Previous.Digest -and $Previous.Id -eq $id -and $candidate.Digest -eq $Previous.Digest) {
            # The files are the ones approved before; only make sure the store still has them.
            Write-Host "The pack $id $($Previous.Version) is up to date."
            $null = Save-MtPackToStore -Path $candidate.Root -Digest $candidate.Digest
            return $Previous
        }
        if ($id -in $Stack) { throw "The packs $(@($Stack + $id) -join ' -> ') require each other in a cycle, which is not allowed." }
        $manifest = $candidate.Manifest

        # Required packs first, each with its own prompt.
        $requiredServices = [System.Collections.Generic.List[string]]::new()
        $requiredIds = [System.Collections.Generic.List[string]]::new()
        foreach ($r in $manifest.RequiredPacks) {
            $requiredIds.Add([string]$r.Id)
            $existing = $Lock.Packs | Where-Object { $_.Id -eq $r.Id } | Select-Object -First 1
            $range = if ($r.PSObject.Properties['Version'] -and $r.Version) { [string]$r.Version } else { $null }
            if ($existing -and (-not $range -or (Test-MtVersionRange -Range $range -Version $existing.Version))) {
                foreach ($s in @($existing.Services)) { $requiredServices.Add($s) }
                continue
            }
            $builtIn = Get-MtBuiltInPack | Where-Object { $_.Id -eq $r.Id } | Select-Object -First 1
            if ($builtIn) {
                foreach ($c in $builtIn.Manifest.Connectors) { $requiredServices.Add([string]$c.Service) }
                continue
            }
            if (-not ($r.PSObject.Properties['Source'] -and $r.Source)) { throw "The pack $id requires $($r.Id), which is not installed and has no Source to install it from." }
            Write-Host "The pack $id requires $($r.Id)$(if ($range) { " $range" }); installing it first."
            $entry = Invoke-MtPackInstall -Source $r.Source -Lock $Lock -Policy $Policy -AcceptRisk $AcceptRisk -IncludeRecent:$IncludeRecent -Force:$Force -NonInteractive:$NonInteractive -Stack @($Stack + $id)
            if ($entry.Id -ne $r.Id) { throw "The pack $id requires $($r.Id) from $($r.Source), but that source holds $($entry.Id)." }
            if ($range -and -not (Test-MtVersionRange -Range $range -Version $entry.Version)) { throw "The pack $id requires $($r.Id) $range, but $($r.Source) has version $($entry.Version)." }
            foreach ($s in @($entry.Services)) { $requiredServices.Add($s) }
        }
        if ($requiredServices.Count -gt 0) {
            # Validate again now that the required packs' services are known.
            $content = Test-MtPackContent -Path $candidate.Root -Official:$candidate.Official -RequiredService $requiredServices.ToArray()
            if ($content.Errors.Count -gt 0) { throw "The pack $id was not installed: $(@($content.Errors | Select-Object -First 5 | ForEach-Object { $_.Message }) -join ' ')" }
        }

        # The Guid names the pack for good. An update must keep it, and keep the code it had with it; another
        # installed pack may not have it.
        $guid = [string]$manifest.Guid
        $earlier = if ($Previous) { $Previous } else { $Lock.Packs | Where-Object { $_.Id -eq $id } | Select-Object -First 1 }
        if ($earlier -and $earlier.PSObject.Properties['Guid'] -and $earlier.Guid) {
            if ($guid -and [string]$earlier.Guid -ne $guid) {
                throw "The pack $id now has the Guid $guid, but the installed pack has $($earlier.Guid), so it is a different pack. Uninstall-MtPack $id first if you want to replace it."
            }
            if ($earlier.PSObject.Properties['Code'] -and $earlier.Code -and [string]$earlier.Code -ne [string]$manifest.Code) {
                throw "The pack $id ($guid) changed its code from $($earlier.Code) to $($manifest.Code). A pack keeps its code: a new code needs a new Guid. Uninstall-MtPack $id first if you want the new pack."
            }
        }
        if ($guid) {
            $twin = $Lock.Packs | Where-Object { $_.Id -ne $id -and $_.PSObject.Properties['Guid'] -and [string]$_.Guid -eq $guid } | Select-Object -First 1
            if ($twin) { throw "The pack $id has the Guid $guid, which the installed pack $($twin.Id) already has." }
        }

        # A code that another pack has, or that is part of its code (CNT and CNT.GWS): their test IDs could clash.
        # The packs that ship with Maester keep theirs.
        $others = @(@(Get-MtBuiltInPack | Where-Object { $_.Manifest } | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Guid = [string]$_.Manifest.Guid; Code = [string]$_.Manifest.Code } }) +
            @($Lock.Packs | Where-Object { $_.PSObject.Properties['Code'] } | ForEach-Object { [pscustomobject]@{ Id = [string]$_.Id; Guid = $(if ($_.PSObject.Properties['Guid']) { [string]$_.Guid }); Code = [string]$_.Code } }))
        foreach ($other in ($others | Where-Object { $_.Id -ne $id })) {
            if (Test-MtPackCodeOverlap -Code ([string]$manifest.Code) -Other $other.Code) {
                throw "The pack $id ($guid) has the code $($manifest.Code), which overlaps the code $($other.Code) of the installed pack $($other.Id)$(if ($other.Guid) { " ($($other.Guid))" }), so their test IDs could clash. Uninstall $($other.Id), or ask the publisher of $id to pick another code."
            }
        }

        # Test IDs that another installed pack provides.
        foreach ($other in ($Lock.Packs | Where-Object { $_.Id -ne $id })) {
            $clash = @($candidate.TestIds | Where-Object { $_ -in @($other.Tests) })
            if ($clash.Count -gt 0) { throw "The pack $id has test IDs that the installed pack $($other.Id) also has: $(@($clash | Select-Object -First 5) -join ', ')." }
        }

        # Modules, with their digests; externally managed ones make the pack High risk.
        if ($candidate.Kind -ne 'BuiltIn' -or @($manifest.Uses.Modules).Count -gt 0) {
            $candidate.Modules = @(Save-MtPackModule -Module @($manifest.Uses.Modules) -AllowExternal:$Policy.AllowExternalEnvironments)
            if ($candidate.Modules | Where-Object Source -EQ 'External') {
                $candidate.Risk = 'High'
                $candidate.Findings.Add([pscustomobject]@{ Severity = 'High'; Code = 'ExternallyManaged'; Message = 'Some of its modules are your own installs rather than modules Maester saved; their digests are pinned now, but where they came from was not checked.'; File = $null; Line = $null })
            }
        }

        $publisher = if ($candidate.Kind -eq 'GitHub') { $candidate.Owner } else { [string]$manifest.Publisher }
        $problem = Test-MtPackPolicy -Policy $Policy -PackId $id -Publisher $publisher -Source $candidate.Source -Digest $candidate.Digest -Risk $candidate.Risk -BuiltIn:($candidate.Kind -eq 'BuiltIn')
        if (-not $problem -and $candidate.Kind -ne 'BuiltIn' -and @($manifest.Uses.UserModules).Count -gt 0 -and -not $Policy.AllowExternalEnvironments) {
            $problem = 'It runs modules you install yourself, and PackPolicy.AllowExternalEnvironments is false.'
        }
        if ($problem) { throw "The pack $id was not installed. $problem" }
        $blocklist = Get-MtPackBlocklist -RequireFresh:$Policy.RequireFreshBlocklist
        if ($blocklist.Warning) { Write-Warning $blocklist.Warning }
        $block = Find-MtPackBlock -Entry $blocklist.Entries -PackId $id -Version $manifest.Version -Digest $candidate.Digest -RepositoryId ([long]$candidate.RepositoryId) -OwnerId ([long]$candidate.OwnerId)
        if ($block -and $block.Severity -ne 'Warn') { throw "The pack $id is blocked: $(ConvertTo-MtPackSafeText $block.Advisory -MaxLength 300)" }
        if ($block) { Write-Warning "The pack $id has an advisory: $(ConvertTo-MtPackSafeText $block.Advisory -MaxLength 300)" }
        if ($candidate.Kind -eq 'GitHub' -and $candidate.UsedToken -and $candidate.Private) { Write-Verbose 'The repository is private; nothing is sent to Maester Packs about it.' }

        if ($candidate.Kind -ne 'BuiltIn') {
            $approval = Show-MtPackApproval -Candidate $candidate -AcceptRisk $AcceptRisk -IncludeRecent:$IncludeRecent -Force:$Force -NonInteractive:$NonInteractive -Previous $Previous
            if (-not $approval.Approved) { throw $approval.Reason }
        }
        if (-not $PSCmdlet.ShouldProcess($id, 'Install the pack')) { return }

        if ($candidate.Kind -ne 'BuiltIn') { $null = Save-MtPackToStore -Path $candidate.Root -Digest $candidate.Digest }

        $entry = [pscustomobject][ordered]@{
            Id                 = $id
            Guid               = $guid
            Version            = [string]$manifest.Version
            Code               = [string]$manifest.Code
            Source             = if ($candidate.Kind -eq 'BuiltIn') { 'builtin' } else { $candidate.Source }
            Ref                = $candidate.Ref
            Commit             = $candidate.Commit
            RepositoryId       = $candidate.RepositoryId
            OwnerId            = $candidate.OwnerId
            Publisher          = $publisher
            Digest             = if ($candidate.Kind -eq 'BuiltIn') { $null } else { $candidate.Digest }
            Tests              = [string[]]$candidate.TestIds
            Services           = [string[]]@($manifest.Connectors | ForEach-Object { [string]$_.Service })
            Requires           = [string[]]$requiredIds.ToArray()
            Risk               = $candidate.Risk
            AcceptedRisk       = $candidate.Risk
            Uses               = $manifest.Uses
            ApprovedAt         = [datetime]::UtcNow.ToString('o', [cultureinfo]::InvariantCulture)
            ReleasePublishedAt = if ($candidate.Release) { $candidate.Release.PublishedAt } else { $null }
            Cooldown           = if ($candidate.Kind -ne 'GitHub') { 'NotApplicable' } elseif ($candidate.CooldownMet) { "Met ($($candidate.AgeSource))" } else { 'Accepted before it was met' }
        }
        $Lock.Packs = @(@($Lock.Packs | Where-Object { $_.Id -ne $id }) + $entry)
        # Modules: this pack's closure replaces what it required before; others keep theirs.
        $modules = [System.Collections.Generic.List[object]]::new()
        foreach ($m in $Lock.Modules) {
            $requiredBy = @(@($m.RequiredBy) | Where-Object { $_ -ne $id })
            if ($requiredBy.Count -gt 0) { $m.RequiredBy = $requiredBy; $modules.Add($m) }
        }
        foreach ($m in $candidate.Modules) {
            $existing = $modules | Where-Object { $_.Name -eq $m.Name -and $_.Version -eq $m.Version } | Select-Object -First 1
            if ($existing) {
                if ($existing.Digest -ne $m.Digest) { throw "The module $($m.Name) $($m.Version) has changed since another pack was approved with it (digest $($existing.Digest), now $($m.Digest))." }
                $existing.RequiredBy = @(@($existing.RequiredBy) + $id | Select-Object -Unique)
            } else {
                $modules.Add([pscustomobject][ordered]@{ Name = $m.Name; Version = $m.Version; Digest = $m.Digest; Source = $m.Source; RequiredBy = @($id) })
            }
        }
        $Lock.Modules = $modules.ToArray()
        $entry
    } finally {
        if ($candidate.Staging) { Remove-Item -LiteralPath $candidate.Staging -Recurse -Force -ErrorAction SilentlyContinue -WhatIf:$false }
    }
}

function Save-MtPackToStore {
    <#
    .SYNOPSIS
    Copies a validated pack into the store under its digest, read-only, and returns the store folder.

    .DESCRIPTION
    A store folder that already exists is kept when its digest still matches; one whose files changed is
    replaced. The copy's digest is checked before it is used, so what is stored is what was approved.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Digest
    )

    $Target = Get-MtPackStorePath -Digest $Digest
    $Exists = Test-Path -LiteralPath $Target
    if ($Exists) {
        if ((Get-MtPackDigest -Path $Target).Digest -eq $Digest) { return $Target }
    }
    # Verify the source as well as the copy, so a bad replacement never removes the stored pack.
    if ((Get-MtPackDigest -Path $Path).Digest -ne $Digest) { throw 'The replacement pack does not match the approved digest.' }
    $Staging = "$Target.$([guid]::NewGuid().ToString('n')).tmp"
    try {
        $null = New-Item -Path $Staging -ItemType Directory -ErrorAction Stop
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop | Copy-Item -Destination $Staging -Recurse -Force -ErrorAction Stop
        $Copied = (Get-MtPackDigest -Path $Staging).Digest
        if ($Copied -ne $Digest) { throw "The pack's files changed while they were copied into the store (digest $Copied, expected $Digest)." }
        if ($Exists) {
            Write-Warning "The stored copy of the pack in '$Target' was changed; it is replaced with the approved files."
            Get-ChildItem -LiteralPath $Target -Recurse -File -Force -ErrorAction Stop | ForEach-Object { if ($IsWindows) { $_.IsReadOnly = $false } }
            Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction Stop
        }
        Move-Item -LiteralPath $Staging -Destination $Target -ErrorAction Stop
        Protect-MtPackFolder -Path $Target
        $Target
    } finally {
        if (Test-Path -LiteralPath $Staging) { Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction Stop }
    }
}

function Get-MtPackStorePath {
    <#
    .SYNOPSIS
    Returns the store folder of a pack digest: store/<hex>.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Digest)
    Join-Path (Get-MtPackHome).Store ($Digest -replace '^sha256:', '')
}
