function Test-MtEntraHardDeletionProtection {
    <#
    .SYNOPSIS
    Checks that the critical Entra objects listed in the Maester config have Hard Deletion Protection enabled.

    .DESCRIPTION
    Takes the HardDeletionProtectedObjects setting as a parameter and checks that each listed user, group, application or
    service principal has isHardDeleteProtectionEnabled set to true. Protection is permanent once enabled, so
    Maester never guesses which objects are critical.

    The result is Failed when a listed object is not protected, is soft deleted or cannot be found. The result
    is Investigate when nothing is listed, or when every listed object is protected but other objects in the
    tenant have protection and are not listed, because the config and the tenant then disagree.

    Hard Deletion Protection is in preview and the property is only available in Microsoft Graph beta.

    .EXAMPLE
    Invoke-Maester -TestId MT.1276 -IncludePreview

    .LINK
    https://maester.dev/docs/tests/MT.1276
    #>
    [MaesterTest(
        Id = 'MT.1276',
        Title = 'Critical Entra objects should have Hard Deletion Protection enabled (Preview).',
        Product = 'entra',
        Feature = 'backup-and-recovery',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1485', 'T1531'),
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'agnivesh'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # The objects to check, from the HardDeletionProtectedObjects setting: a Type and an Id each.
        [MaesterParameter(Setting = 'HardDeletionProtectedObjects')]
        [object[]] $HardDeletionProtectedObjects = @()
    )

    $ConfiguredObjects = @($HardDeletionProtectedObjects | Where-Object { $_ })
    $Protected = @(Get-MtEntraHardDeletionProtectedObject)

    if ($ConfiguredObjects.Count -eq 0) {
        $Result = 'No objects are listed in HardDeletionProtectedObjects in the Maester config, so Hard Deletion ' +
            "Protection must be verified manually.`n`n"
        if ($Protected.Count -gt 0) {
            $Result += "These $($Protected.Count) object(s) have Hard Deletion Protection in Microsoft Entra. " +
                "Add the ones that matter to the config so this test can check them:`n`n"
            $Result += Format-MtEntraHardDeletionTable -InputObject $Protected -StateProperty State -StateHeading State
        } else {
            $Result += 'The scan did not find any objects with Hard Deletion Protection. Add the critical users, ' +
                'groups, applications and service principals to protect to GlobalSettings.' +
                'HardDeletionProtectedObjects, then enable protection on them. See ' +
                'https://maester.dev/docs/configuration/hard-deletion-protection for the format.'
        }
        Add-MtTestResultDetail -Investigate -Result $Result
        return $null
    }

    $ListedKeys = @{}
    $Rows = @(
        foreach ($Configured in $ConfiguredObjects) {
            $Row = Get-MtEntraHardDeletionObjectStatus -Configured $Configured
            $Key = "$($Row.Type)|$($Row.Id)"
            if (-not $ListedKeys.ContainsKey($Key)) {
                $ListedKeys[$Key] = $true
                $Row
            }
        }
    )
    $Unlisted = @($Protected | Where-Object { -not $ListedKeys.ContainsKey("$($_.Type)|$($_.Id)") })
    $UnlistedTable = if ($Unlisted.Count -gt 0) {
        "`n`n$($Unlisted.Count) other object(s) have Hard Deletion Protection in Microsoft Entra but are not " +
            "listed in the Maester config:`n`n" +
            (Format-MtEntraHardDeletionTable -InputObject $Unlisted -StateProperty State -StateHeading State)
    } else {
        ''
    }

    $Failing = @($Rows | Where-Object { $_.Status -ne 'Protected' })
    if ($Failing.Count -gt 0) {
        $Result = "$($Failing.Count) of $($Rows.Count) listed object(s) do not have Hard Deletion Protection " +
            "enabled, or are deleted or missing.`n`n" +
            (Format-MtEntraHardDeletionTable -InputObject $Failing -StateProperty Status -StateHeading Status)
        Add-MtTestResultDetail -Result ($Result + $UnlistedTable)
        return $false
    }

    if ($Unlisted.Count -gt 0) {
        $Result = "All $($Rows.Count) listed object(s) have Hard Deletion Protection enabled. Check whether the " +
            'other protected objects below belong in the Maester config.' + $UnlistedTable
        Add-MtTestResultDetail -Investigate -Result $Result
        return $null
    }

    Add-MtTestResultDetail -Result "Well done. All $($Rows.Count) listed object(s) have Hard Deletion Protection enabled."
    return $true
}
