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
                HasVersionMismatch    = $false
                CpasswordFound         = $false
                DefaultPasswordFound  = $false
            }
        }

        foreach ($link in @($gpoState.GPOLinks | Where-Object { $null -ne $_ })) {
            if ($null -eq $link.gPLink) { continue }
            $linkEntries = ($link.gPLink -split '\]' | Where-Object { $_ -match 'LDAP://' })
            foreach ($entry in $linkEntries) {
                if ($entry -notmatch 'CN=\{?([0-9a-fA-F-]{36})\}?,' ) { continue }
                $policyGuid = $matches[1]
                if ($entry -notmatch ';(\d)$') { continue }
                $linkState = [int]$matches[1]
                if (-not $gpoReportsById.ContainsKey($policyGuid)) { continue }
                switch ($linkState) {
                    1 { $gpoReportsById[$policyGuid].DisabledLinks++ }
                    2 { $gpoReportsById[$policyGuid].Enforcement++ }
                }
            }
        }

        foreach ($gpo in $gpos) {
            $guid = [string]$gpo.Id
            $reportObj = $gpoReportsById[$guid]
            if ($null -eq $reportObj) { continue }

            try {
                $xmlText = Get-GPOReport -Guid $guid -ReportType Xml -ErrorAction Stop
                if ($xmlText -match '(?i)Apply\s+Group\s+Policy') {
                    $reportObj.HasApplyGroupPolicyAce = $true
                }
                if ($xmlText -match '(?i)version\s+mismatch') {
                    $reportObj.HasVersionMismatch = $true
                }
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
    $noApplyAceReports = @($gpoReportsArray | Where-Object { -not [bool]$_.HasApplyGroupPolicyAce })

    $table = "| GPO Name | HasApplyGroupPolicyAce |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in ($noApplyAceReports | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\\|', '\\&#124;'
        $table += "| $name | $([bool]$report.HasApplyGroupPolicyAce) |`n"
    }

    $testResult = $true
    $testResultMarkdown = "GPO apply permissions were analyzed. $($noApplyAceReports.Count) GPO(s) are missing the required ACE.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
