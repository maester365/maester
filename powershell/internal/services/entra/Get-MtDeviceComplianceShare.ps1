function Get-MtDeviceComplianceShare {
    <#
    .SYNOPSIS
    Counts the devices that signed in recently and are marked compliant, for the devices-compliant measure.

    .DESCRIPTION
    The reader of the devices-compliant measure (powershell/assets/MaesterMeasures.psd1), which decides the step
    intune.devices-compliant of the defender's path. A Conditional Access policy that requires a compliant device
    blocks every device that Microsoft Entra ID doesn't mark compliant, so the share of compliant devices among the
    devices in use says whether such a policy can be turned on.

    Reads the enabled devices in Microsoft Entra ID that signed in within the last SignedInWithinDays days
    (approximateLastSignInDateTime), through the Graph cache. A device counts when isCompliant is true: Intune sets
    it, also for the devices of a compliance partner, and it is what a compliant-device grant checks. The measure
    declares the Intune licence, so a tenant without Intune gets no figure. Devices that are not compliant are
    returned as the objects that fall short, most recent sign-in first, whether they are managed (isManaged) and
    noncompliant or not managed at all.

    A device that has no Microsoft Entra identity (neither registered nor joined) can't be seen this way, so it is
    neither counted nor listed. A compliant-device policy blocks it too.

    Returns an object with Count (compliant devices), Total (devices that signed in) and Objects (the devices that
    aren't compliant, as Type, Id and DisplayName).

    For each device it lists, it adds the object facts device.managed, device.compliant, device.os and device.joinType
    (design section 12) with Add-MtAffectedObjectFact, from the source 'Maester measures'. The engine puts the
    objects of a measure on the Affected objects page, so the facts have an object to attach to. A run that doesn't
    collect affected objects keeps no facts.

    .EXAMPLE
    Get-MtDeviceComplianceShare

    Returns the number of compliant devices among the enabled devices that signed in within the last 30 days.

    .EXAMPLE
    Get-MtDeviceComplianceShare -SignedInWithinDays 14

    Counts only the devices that signed in within the last 14 days.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Devices that signed in within this many days are counted. approximateLastSignInDateTime is approximate, so
        # keep it well above a week.
        [ValidateRange(1, 365)]
        [int] $SignedInWithinDays = 30
    )

    # Start of the UTC day, so the request, and so its cache entry, stays the same for the whole day.
    $since = [datetime]::UtcNow.Date.AddDays(-$SignedInWithinDays).ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
    $deviceSplat = @{
        RelativeUri     = 'devices'
        Filter          = "accountEnabled eq true and approximateLastSignInDateTime ge $since"
        # isManaged, operatingSystem and trustType are read for the object facts device.managed, device.os and
        # device.joinType (design section 12).
        Select          = 'id', 'displayName', 'approximateLastSignInDateTime', 'isCompliant', 'isManaged', 'operatingSystem', 'trustType'
        QueryParameters = @{ '$count' = 'true' }
    }
    $devices = @(Invoke-MtGraphRequest @deviceSplat | Where-Object { $null -ne $_ })

    $notCompliant = @($devices | Where-Object { $_.isCompliant -ne $true })

    # Object facts for the devices listed, with the shared keys.
    $joinTypes = @{ AzureAd = 'Microsoft Entra joined'; ServerAd = 'Microsoft Entra hybrid joined'; Workplace = 'Microsoft Entra registered' }
    $facts = foreach ($device in $notCompliant) {
        if (-not $device.id) { continue }
        $managed = $device.isManaged -eq $true
        $list = [System.Collections.Generic.List[object]]::new()
        $list.Add(@{ Name = 'Management'; Value = $(if ($managed) { 'Managed' } else { 'Not managed' }); Tone = $(if ($managed) { 'Info' } else { 'Warning' }); Key = 'device.managed'; Raw = $managed })
        $list.Add(@{ Name = 'Compliance'; Value = 'Not compliant'; Tone = 'Warning'; Key = 'device.compliant'; Raw = $false })
        if ($device.operatingSystem) { $list.Add(@{ Name = 'Operating system'; Value = [string]$device.operatingSystem; Key = 'device.os'; Raw = [string]$device.operatingSystem }) }
        $trust = [string]$device.trustType
        if ($trust) { $list.Add(@{ Name = 'Join type'; Value = $(if ($joinTypes.ContainsKey($trust)) { $joinTypes[$trust] } else { $trust }); Key = 'device.joinType'; Raw = $trust }) }
        [pscustomobject]@{ Type = 'Device'; Id = [string]$device.id; Fact = $list.ToArray() }
    }
    if (@($facts).Count -gt 0) { $facts | Add-MtAffectedObjectFact -Source 'Maester measures' }

    [pscustomobject][ordered]@{
        Count   = $devices.Count - $notCompliant.Count
        Total   = $devices.Count
        Objects = @(
            $notCompliant |
                Sort-Object -Property @{ Expression = { $_.approximateLastSignInDateTime -as [datetime] }; Descending = $true }, displayName, id |
                ForEach-Object {
                    [pscustomobject][ordered]@{
                        Type        = 'Device'
                        Id          = [string]$_.id
                        DisplayName = [string]$_.displayName
                    }
                }
        )
    }
}
