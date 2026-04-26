<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoNoApplyGroupPolicyAceCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs missing the "Apply Group Policy" ACE.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes each GPO report for whether it has an ACE granting the "Apply Group Policy" right.

    .EXAMPLE
    Test-MtAdGpoNoApplyGroupPolicyAceCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the count of GPOs without the required "Apply Group Policy" ACE.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoApplyGroupPolicyAceCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoNoApplyGroupPolicyAceCount"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no apply group policy ace count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })

    $gpoCount = $gpoReportsArray.Count
    $noApplyAceCount = @($gpoReportsArray | Where-Object { -not [bool]$_.HasApplyGroupPolicyAce }).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $gpoCount |`n"
    $result += "| GPOs missing Apply Group Policy ACE | $noApplyAceCount |`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for Apply Group Policy permissions. $noApplyAceCount out of $gpoCount GPO(s) are missing the required ACE.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoNoApplyGroupPolicyAceCount"
    return $testResult
}


