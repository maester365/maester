<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoCpasswordFoundCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that contain a cpassword (GPP password).

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes each GPO report to count how many report entries indicate that a cpassword
    is present in Group Policy Preferences.

    .EXAMPLE
    Test-MtAdGpoCpasswordFoundCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the number of GPOs with cpassword found.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoCpasswordFoundCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpoReports = $null
    if ($null -ne $gpoState.GPOReports) {
        $gpoReports = @($gpoState.GPOReports | Where-Object { $null -ne $_ })
    }

    if ($null -eq $gpoReports) {
        $gpos = @($gpoState.GPOs | Where-Object { $null -ne $_ })
        if ($null -eq $gpos) {
            Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO objects from Get-MtADGpoState.'
            return $false
        }

        $gpoReportsById = @{}
        foreach ($gpo in $gpos) {
            $gpoReportsById[[string]$gpo.Id] = [pscustomobject]@{
                Name                    = [string]$gpo.DisplayName
                HasApplyGroupPolicyAce = $false
                DisabledLinks          = 0
                Enforcement            = 0
                HasVersionMismatch     = $false
                CpasswordFound         = $false
                DefaultPasswordFound  = $false
            }
        }

        foreach ($gpo in $gpos) {
            $guid = [string]$gpo.Id
            $reportObj = $gpoReportsById[$guid]
            if ($null -eq $reportObj) { continue }
            try {
                $xmlText = Get-GPOReport -Guid $guid -ReportType Xml -ErrorAction Stop
                if ($xmlText -match '(?i)cpassword') {
                    $reportObj.CpasswordFound = $true
                    $reportObj.DefaultPasswordFound = $true
                }
                if ($xmlText -match '(?i)Apply\s+Group\s+Policy') { $reportObj.HasApplyGroupPolicyAce = $true }
                if ($xmlText -match '(?i)version\s+mismatch') { $reportObj.HasVersionMismatch = $true }
            }
            catch {
            }
        }

        $gpoReports = @($gpoReportsById.Values)
    }

    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $totalCount = $gpoReportsArray.Count
    $cpasswordCount = @($gpoReportsArray | Where-Object { [bool]$_.CpasswordFound }).Count

    $testResult = $true
    $cpasswordPercentage = if ($totalCount -gt 0) { [Math]::Round(($cpasswordCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with cpassword | $cpasswordCount |`n"
    $result += "| cpassword ratio | $cpasswordPercentage% |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for cpassword usage. $cpasswordCount out of $totalCount GPO(s) contain a cpassword.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
