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
    (approximateLastSignInDateTime), through the Graph cache. A device counts when isCompliant is true: Intune or
    an approved MDM sets it, and it is what a compliant-device grant checks. Devices that are not compliant are
    returned as the objects that fall short, most recent sign-in first, whether they are managed (isManaged) and
    noncompliant or not managed at all.

    A device that has no Microsoft Entra identity (neither registered nor joined) can't be seen this way, so it is
    neither counted nor listed. A compliant-device policy blocks it too.

    Returns an object with Count (compliant devices), Total (devices that signed in) and Objects (the devices that
    aren't compliant, as Type, Id and DisplayName).

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
        # device.joinType (design section 12), which this reader writes once Add-MtAffectedObjectFact takes a Key.
        Select          = 'id', 'displayName', 'approximateLastSignInDateTime', 'isCompliant', 'isManaged', 'operatingSystem', 'trustType'
        QueryParameters = @{ '$count' = 'true' }
    }
    $devices = @(Invoke-MtGraphRequest @deviceSplat | Where-Object { $null -ne $_ })

    $notCompliant = @($devices | Where-Object { $_.isCompliant -ne $true })

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
