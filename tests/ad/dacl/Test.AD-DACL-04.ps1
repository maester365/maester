function Test-MtAdDaclConflictObjectDetails {
    <#
    .SYNOPSIS
    Returns detailed information for conflict objects represented in DACL data.

    .DESCRIPTION
    This informational test identifies conflict objects in the DACL dataset by searching for CNF in
    the object distinguished name, then returns a detailed breakdown of each affected object. The
    output helps administrators review replication-conflict remnants and understand how many ACEs are
    associated with each conflict object.

    .EXAMPLE
    Test-MtAdDaclConflictObjectDetails

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclConflictObjectDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-DACL-04',
        Title = 'Conflict object details should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl'),
        LongRunning,
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclConflictObjectDetails"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }
    if ($null -eq $adState.DaclEntries) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'DACL data is unavailable.'
        return $null
    }
    Write-Verbose "Filtering/counting dacl conflict object details"

    $daclEntries = @($adState.DaclEntries)
    $conflictEntries = @($daclEntries | Where-Object { $_.ObjectDN -match 'CNF' })
    $conflictGroups = @($conflictEntries | Group-Object -Property ObjectDN | Sort-Object -Property Count, Name -Descending)
    $conflictObjectCount = ($conflictGroups | Measure-Object).Count
    $conflictAceCount = ($conflictEntries | Measure-Object).Count
    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Conflict Objects | $conflictObjectCount |" + "`n"
    $result += "| DACL Entries On Conflict Objects | $conflictAceCount |" + "`n" + "`n"

    if ($conflictObjectCount -gt 0) {
        $result += "| Object DN | Object Class | ACE Count |" + "`n"
        $result += "| --- | --- | --- |" + "`n"

        foreach ($group in $conflictGroups) {
            $sample = $group.Group | Select-Object -First 1
            $objectDn = if ($null -ne $sample.ObjectDN) { ([string]$sample.ObjectDN) -replace '\|', '\\&#124;' } else { '' }
            $objectClass = if ($null -ne $sample.ObjectClass) { ([string]$sample.ObjectClass) -replace '\|', '\\&#124;' } else { '' }
            $result += "| $objectDn | $objectClass | $($group.Count) |" + "`n"
        }
    } else {
        $result += "**No conflict objects were identified in the collected DACL data.**" + "`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory DACL conflict-object details have been compiled. $conflictObjectCount conflict object(s) were identified in the dataset.`n`n%TestResult%"
    if ($conflictObjectCount -gt 0) {
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", ""
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclConflictObjectDetails"
    return $testResult
}
