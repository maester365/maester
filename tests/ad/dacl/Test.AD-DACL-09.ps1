function Test-MtAdDaclPrivilegedAllowAceCount {
    <#
    .SYNOPSIS
    Counts privileged allow ACEs and lists affected objects in collected DACL data.

    .DESCRIPTION
    This test identifies allow ACEs that include high-impact Active Directory rights
    such as GenericAll, WriteDacl, WriteOwner, or ExtendedRight. These rights can
    enable broad control over directory objects and should be monitored carefully.

    .EXAMPLE
    Test-MtAdDaclPrivilegedAllowAceCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclPrivilegedAllowAceCount
    #>
    [MaesterTest(
        Id = 'AD-DACL-09',
        Title = 'Privileged allow ACEs and affected objects should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'privileged-access',
        ResourceType = 'Permission',
        Severity = 'Info',
        Mitre = ('T1098', 'T1222.001'),
        Service = 'ActiveDirectory',
        Platform = 'Windows',
        Permission = ('ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl'),
        LongRunning,
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclPrivilegedAllowAceCount"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }
    Write-Verbose "Filtering/counting dacl privileged allow ace count"

    $privilegedRights = @('GenericAll', 'WriteDacl', 'WriteOwner', 'ExtendedRight')
    $getPrivilegedRights = {
        param($rightsText)

        @(
            foreach ($right in $privilegedRights) {
                if ([string]$rightsText -match "(^|,\s*)$right(,|$)") {
                    $right
                }
            }
        )
    }

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess privileged ACEs.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) -or [string]::IsNullOrWhiteSpace($_.AccessControlType) -or [string]::IsNullOrWhiteSpace($_.ActiveDirectoryRights) }).Count -gt 0) {
        throw 'DACL entries are missing object names, access control types or rights.'
    }
    $privilegedAllowEntries = @(
        foreach ($entry in $daclEntries) {
            if ($entry.AccessControlType -ne 'Allow') {
                continue
            }

            $matchedRights = @(& $getPrivilegedRights $entry.ActiveDirectoryRights)
            if ($matchedRights.Count -gt 0) {
                [PSCustomObject]@{
                    ObjectDN = $entry.ObjectDN
                    ObjectClass = $entry.ObjectClass
                    ObjectName = $entry.ObjectName
                    IdentityReference = $entry.IdentityReference
                    MatchedRights = $matchedRights
                }
            }
        }
    )

    $testResult = $null -ne $adState.DaclEntries

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total DACL ACEs | $((@($daclEntries) | Measure-Object).Count) |" + "`n"
    $result += "| Privileged allow ACEs | $($privilegedAllowEntries.Count) |" + "`n"
    $result += "| Distinct objects with privileged allow ACEs | $(@($privilegedAllowEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } | Select-Object -ExpandProperty ObjectDN -Unique).Count) |" + "`n"
    $result += "| Distinct identities with privileged allow ACEs | $(@($privilegedAllowEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } | Select-Object -ExpandProperty IdentityReference -Unique).Count) |" + "`n"

    foreach ($right in $privilegedRights) {
        $rightCount = @($privilegedAllowEntries | Where-Object { $_.MatchedRights -contains $right }).Count
        $result += "| ACEs containing $right | $rightCount |" + "`n"
    }
    $result += "`n| Object Name | Object Class | ACE Count | Distinct Identities | Privileged Rights | Object DN |`n| --- | --- | --- | --- | --- | --- |`n"
    foreach ($group in @($privilegedAllowEntries | Group-Object ObjectDN | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $sample = $group.Group | Select-Object -First 1
        $objectName = ([string]$sample.ObjectName) -replace '\|', '&#124;'
        $objectClass = ([string]$sample.ObjectClass) -replace '\|', '&#124;'
        $objectDn = ([string]$sample.ObjectDN) -replace '\|', '&#124;'
        $identityCount = @($group.Group | Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } | Select-Object -ExpandProperty IdentityReference -Unique).Count
        $rights = (@($group.Group | ForEach-Object { $_.MatchedRights } | Sort-Object -Unique) -join ', ') -replace '\|', '&#124;'
        $result += "| $objectName | $objectClass | $($group.Count) | $identityCount | $rights | $objectDn |`n"
    }
    if ($privilegedAllowEntries.Count -eq 0) {
        $result += "| No privileged allow ACEs found | | 0 | 0 | | |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "This informational test counts allow ACEs that grant high-impact Active Directory rights.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclPrivilegedAllowAceCount"
    return $testResult
}
