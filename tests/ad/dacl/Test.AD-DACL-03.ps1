function Test-MtAdDaclConflictObjectCount {
    <#
    .SYNOPSIS
    Counts conflict objects represented in DACL data.

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
        Title = 'Conflict object count should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
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
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }
    if ($null -eq $adState.DaclEntries) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'DACL data is unavailable.'
        return $null
    }
    Write-Verbose "Filtering/counting dacl conflict object count"

    $daclEntries = @($adState.DaclEntries)
    $conflictEntries = @($daclEntries | Where-Object { $_.ObjectDN -match 'CNF' })
    $conflictObjectDns = @(
        $conflictEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
            Select-Object -ExpandProperty ObjectDN -Unique
    )

    $conflictObjectCount = ($conflictObjectDns | Measure-Object).Count
    $conflictAceCount = ($conflictEntries | Measure-Object).Count
    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Conflict Objects In DACL Data | $conflictObjectCount |" + "`n"
    $result += "| DACL Entries On Conflict Objects | $conflictAceCount |" + "`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory DACL data has been reviewed for conflict objects. $conflictObjectCount conflict object(s) with CNF markers were identified in the DACL dataset.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclConflictObjectCount"
    return $testResult
}
