<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoVersionMismatchDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs with a version mismatch.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes each GPO report to return a markdown table listing GPOs with a version mismatch.

    .EXAMPLE
    Test-MtAdGpoVersionMismatchDetails

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes a markdown table listing mismatched GPOs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoVersionMismatchDetails
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
                if ($xmlText -match '(?i)version\s+mismatch') { $reportObj.HasVersionMismatch = $true }
                if ($xmlText -match '(?i)Apply\s+Group\s+Policy') { $reportObj.HasApplyGroupPolicyAce = $true }
                if ($xmlText -match '(?i)cpassword') {
                    $reportObj.CpasswordFound = $true
                    $reportObj.DefaultPasswordFound = $true
                }
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
    $mismatched = @($gpoReportsArray | Where-Object { [bool]$_.HasVersionMismatch })
    $mismatchCount = @($mismatched).Count

    $table = "| GPO Name | HasVersionMismatch |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in ($mismatched | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\|', '\\&#124;'
        $table += "| $name | $([bool]$report.HasVersionMismatch) |`n"
    }

    $recommendation = if ($mismatchCount -gt 0) {
        "GPO version mismatch details were returned ($mismatchCount). Review these GPOs to ensure their versions are consistent."
    }
    else {
        '✅ No GPO version mismatches were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    $testResult = $true
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
