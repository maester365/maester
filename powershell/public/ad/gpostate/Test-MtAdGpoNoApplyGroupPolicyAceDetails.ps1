<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoNoApplyGroupPolicyAceDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs missing the "Apply Group Policy" ACE.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes each GPO report to identify which GPOs are missing the ACE required for
    applying group policy.

    .EXAMPLE
    Test-MtAdGpoNoApplyGroupPolicyAceDetails

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes a markdown table listing GPOs missing the required ACE.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoApplyGroupPolicyAceDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $noApplyAceReports = @($gpoReportsArray | Where-Object { -not [bool]$_.HasApplyGroupPolicyAce })

    $table = "| GPO Name | HasApplyGroupPolicyAce |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in ($noApplyAceReports | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\|', '\\&#124;'
        $table += "| $name | $([bool]$report.HasApplyGroupPolicyAce) |`n"
    }

    $testResult = $true
    $testResultMarkdown = "GPO apply permissions were analyzed. $($noApplyAceReports.Count) GPO(s) are missing the required ACE.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
