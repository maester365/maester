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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }

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

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Conflict Objects In DACL Data | $conflictObjectCount |`n"
    $result += "| DACL Entries On Conflict Objects | $conflictAceCount |`n"

    $testResultMarkdown = "Active Directory DACL data has been reviewed for conflict objects. $conflictObjectCount conflict object(s) with CNF markers were identified in the DACL dataset.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
