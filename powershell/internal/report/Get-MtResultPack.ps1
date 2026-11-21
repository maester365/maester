function Get-MtResultPack {
    <#
    .SYNOPSIS
    Builds the Packs list of a result: one entry for each Maester Pack the run loaded or tried to load.

    .DESCRIPTION
    Each pack row carries Package (Id, Name, Version, Commit, Publisher, BuiltIn, Runtime), which is enough to
    group rows but not to describe the pack. A report shows a pack with its code, description, home page and
    the risk level the user accepted at install, and says why a pack did not run. For each pack of the run's
    pack set (Initialize-MtPackSet) that is not Disabled, this returns Id, Code, Name, Description, Version,
    Publisher, BuiltIn, Homepage, Risk, Status, ReasonCode and Reason, plus Logo, Navigation and Guide when the pack
    has them: Navigation is the manifest's Report.Navigation, the pack's menu in the report, and Guide is the
    pack's guide file (how to install, connect and run it), which the menu's guide pages show. Both are JSON
    text, not objects: the result is written with a fixed depth that would cut a deep menu short.

    Risk is the AcceptedRisk of the pack's lock entry, $null for a pack that ships with Maester. Status is
    Ready, or the status that kept the pack from running (Failed, Blocked, NotAllowed, Unavailable), with its
    ReasonCode and Reason.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The run's pack set (Initialize-MtPackSet).
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $PackSet = @()
    )

    # The guide is read only for a pack whose menu shows it, and a guide that cannot be read is left out.
    $readGuide = {
        param($pack)
        $manifest = $pack.Manifest
        if (-not ($manifest -and $pack.PSObject.Properties['Root'] -and $pack.Root -and $manifest.PSObject.Properties['Guide'] -and $manifest.Guide -is [string])) { return }
        if (-not ($manifest.PSObject.Properties['Report'] -and $manifest.Report -is [pscustomobject] -and ($manifest.Report | ConvertTo-Json -Depth 20 -Compress) -match '"View":"guide"')) { return }
        try { Get-Content -LiteralPath (Join-Path $pack.Root $manifest.Guide) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | ConvertTo-Json -Depth 30 -Compress } catch { $null }
    }

    foreach ($pack in $PackSet) {
        if ($null -eq $pack -or $pack.Status -eq 'Disabled') { continue }
        $manifest = $pack.Manifest
        $entry = $pack.Entry
        $read = {
            param($source, $name)
            if ($source -and $source.PSObject.Properties[$name] -and $null -ne $source.$name -and "$($source.$name)" -ne '') { [string]$source.$name }
        }
        [pscustomobject][ordered]@{
            Id          = [string]$pack.Id
            Code        = & $read $manifest 'Code'
            Name        = if (& $read $manifest 'Name') { & $read $manifest 'Name' } else { [string]$pack.Id }
            Description = & $read $manifest 'Description'
            Version     = if ($pack.Version) { [string]$pack.Version } else { & $read $entry 'Version' }
            Publisher   = if (& $read $manifest 'Publisher') { & $read $manifest 'Publisher' } else { & $read $entry 'Publisher' }
            BuiltIn     = [bool]$pack.BuiltIn
            Homepage    = & $read $manifest 'Homepage'
            Risk        = if ($pack.BuiltIn) { $null } else { & $read $entry 'AcceptedRisk' }
            Status      = [string]$pack.Status
            ReasonCode  = $pack.ReasonCode
            Reason      = $pack.Reason
            Logo        = if ($manifest -and $manifest.PSObject.Properties['Report'] -and $manifest.Report -is [pscustomobject] -and $manifest.Report.PSObject.Properties['Logo']) { [string]$manifest.Report.Logo }
            Navigation  = if ($manifest -and $manifest.PSObject.Properties['Report'] -and $manifest.Report -is [pscustomobject] -and $manifest.Report.PSObject.Properties['Navigation']) { ConvertTo-Json -InputObject @($manifest.Report.Navigation) -Depth 30 -Compress }
            Guide       = & $readGuide $pack
        }
    }
}
