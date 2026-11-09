function Test-MtAdDaclInheritedObjectTypeCount {
    <#
    .SYNOPSIS
    Counts inherited object type GUIDs and lists their ACE distribution.

    .DESCRIPTION
    This test analyzes DACL entries from Get-MtADDomainState -Categories @('DaclEntries') and counts distinct
    inherited object type GUIDs that are explicitly targeted by ACE inheritance.
    Reviewing inherited object type scope helps identify how broadly delegated access
    applies to descendant object classes.

    .EXAMPLE
    Test-MtAdDaclInheritedObjectTypeCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclInheritedObjectTypeCount
    #>
    [MaesterTest(
        Id = 'AD-DACL-17',
        Title = 'Inherited object type counts and details should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'access-control',
        ResourceType = 'Permission',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Platform = 'Windows',
        Permission = ('ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl'),
        LongRunning,
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclInheritedObjectTypeCount"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }
    Write-Verbose "Filtering/counting dacl inherited object type count"

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess inheritance targeting.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) }).Count -gt 0) {
        throw 'DACL entries are missing object distinguished names.'
    }
    $filteredEntries = @(
        $daclEntries | Where-Object {
            $inheritedObjectType = [string]$_.InheritedObjectType
            -not [string]::IsNullOrWhiteSpace($inheritedObjectType) -and
            $inheritedObjectType -ne '00000000-0000-0000-0000-000000000000'
        }
    )

    $distinctInheritedObjectTypeCount = @(
        $filteredEntries |
            Group-Object -Property InheritedObjectType
    ).Count

    $testResult = $null -ne $adState.DaclEntries

    $result = '| Metric | Value |' + "`n"
    $result += '| --- | --- |' + "`n"
    $result += "| Total DACL Entries | $($daclEntries.Count) |" + "`n"
    $result += "| ACEs with Specific InheritedObjectType | $($filteredEntries.Count) |" + "`n"
    $result += "| Distinct InheritedObjectType GUIDs | $distinctInheritedObjectTypeCount |" + "`n"
    $result += "`n| InheritedObjectType | ACE Count | Distinct ObjectDN Count |`n| --- | --- | --- |`n"
    foreach ($group in @($filteredEntries | Group-Object InheritedObjectType | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $inheritedObjectType = ([string]$group.Name) -replace '\|', '&#124;'
        $objects = @($group.Group | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } | Select-Object -ExpandProperty ObjectDN -Unique).Count
        $result += "| $inheritedObjectType | $($group.Count) | $objects |`n"
    }
    if ($filteredEntries.Count -eq 0) {
        $result += "| No specific inherited object type GUIDs found | 0 | 0 |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory DACL inheritance targets were analyzed. $distinctInheritedObjectTypeCount distinct inherited object type GUID(s) were referenced across $($filteredEntries.Count) ACE(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclInheritedObjectTypeCount"
    return $testResult
}
