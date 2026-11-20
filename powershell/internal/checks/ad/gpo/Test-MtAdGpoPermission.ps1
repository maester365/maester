function Test-MtAdGpoPermission {
    <#
    .SYNOPSIS
    Evaluates a cached GPO permission summary and formats findings and unknown values.
    .DESCRIPTION
    Multiple permission properties are alternatives: one matching value proves the
    condition. With no matching value, an unknown alternative remains inconclusive.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string[]] $PermissionProperties,
        [Parameter(Mandatory)]
        [bool] $ExpectedValue,
        [Parameter(Mandatory)]
        [string] $FindingLabel,
        [Parameter(Mandatory)]
        [string] $PassMessage,
        [Parameter(Mandatory)]
        [string] $FailureMessage
    )

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports) { throw 'GPO permission data could not be collected.' }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    $assessed = @(foreach ($report in $reports) {
            $matchedValue = $false
            $hasUnknown = $false
            foreach ($property in $PermissionProperties) {
                if ($null -eq $report.$property) { $hasUnknown = $true }
                elseif ($report.$property -eq $ExpectedValue) { $matchedValue = $true }
            }
            $assessment = if ($matchedValue) { 'Expected' }
            elseif ($hasUnknown) { 'Unknown' }
            else { 'Finding' }
            [pscustomobject]@{ Name = $report.Name; Assessment = $assessment }
        })
    $findings = @($assessed | Where-Object Assessment -EQ 'Finding')
    $unknown = @($assessed | Where-Object Assessment -EQ 'Unknown')
    if ($unknown.Count -eq $reports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permission conditions could not be determined (0 of $($reports.Count) GPOs evaluated). Descriptors may be unreadable or contain conflicting allow and deny entries."
        return $null
    }
    $pass = $findings.Count -eq 0
    $summary = if ($pass -and $unknown.Count -eq 0) { "Well done. $PassMessage" }
    elseif ($pass) { 'No findings among evaluated GPOs; incomplete or inconclusive permissions require investigation.' }
    else { "$($findings.Count) of $($reports.Count) GPOs $FailureMessage" }
    if ($unknown.Count -gt 0) { $summary += " Permission conditions could not be determined for $($unknown.Count) GPOs; inspect unreadable descriptors or conflicting allow and deny entries." }
    $metrics = [ordered]@{ 'Total GPOs' = $reports.Count; $FindingLabel = $findings.Count; 'GPOs with unknown permissions' = $unknown.Count }
    if ($PermissionProperties -contains 'HasDomainComputers') {
        $metrics['GPOs without Domain Computers'] = @($reports | Where-Object { $false -eq $_.HasDomainComputers }).Count
    }
    $details = @($findings + $unknown | Sort-Object Name)
    $result = Format-MtAdGpoResult -Summary $summary -Metrics $metrics -Details $details -Properties Name, Assessment -Headers GPO, Assessment
    Add-MtTestResultDetail -Result $result -Investigate:($pass -and $unknown.Count -gt 0)
    return $pass
}
