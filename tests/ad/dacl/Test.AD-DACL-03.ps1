function Test-MtAdDaclConflictObjectCount {
    <#
    .SYNOPSIS
    Counts conflict objects and lists their DACL entries by object.

    .DESCRIPTION
    This informational test identifies conflict objects in collected DACL data by looking for CNF
    markers in object distinguished names. Conflict objects are commonly created during replication
    collisions or object naming conflicts and can indicate cleanup opportunities or historical AD
    issues that deserve administrative review.

    .EXAMPLE
    Test-MtAdDaclConflictObjectCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclConflictObjectCount
    #>
    [MaesterTest(
        Id = 'AD-DACL-03',
        Title = 'Conflict objects and their DACL entries should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
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

    Write-Verbose "Starting Test-MtAdDaclConflictObjectCount"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }
    Write-Verbose "Filtering/counting dacl conflict object count"

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess conflict objects.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) }).Count -gt 0) {
        throw 'DACL entries are missing object distinguished names.'
    }
    $conflictEntries = @($daclEntries | Where-Object { [string]$_.ObjectDN -match '\\0ACNF:' })
    $conflictObjectDns = @(
        $conflictEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
            Select-Object -ExpandProperty ObjectDN -Unique
    )

    $conflictObjectCount = ($conflictObjectDns | Measure-Object).Count
    $conflictAceCount = ($conflictEntries | Measure-Object).Count
    $testResult = $null -ne $adState.DaclEntries

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Conflict Objects In DACL Data | $conflictObjectCount |" + "`n"
    $result += "| DACL Entries On Conflict Objects | $conflictAceCount |" + "`n"
    $result += "`n| Object DN | Object Class | ACE Count |`n| --- | --- | --- |`n"
    foreach ($group in @($conflictEntries | Group-Object ObjectDN | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $sample = $group.Group | Select-Object -First 1
        $objectDn = ([string]$sample.ObjectDN) -replace '\|', '&#124;'
        $objectClass = ([string]$sample.ObjectClass) -replace '\|', '&#124;'
        $result += "| $objectDn | $objectClass | $($group.Count) |`n"
    }
    if ($conflictObjectCount -eq 0) {
        $result += "| No conflict objects found | | 0 |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory DACL data contains $conflictObjectCount conflict object(s) with CNF markers.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclConflictObjectCount"
    return $testResult
}
