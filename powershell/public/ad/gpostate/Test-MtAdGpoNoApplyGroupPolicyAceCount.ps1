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
        # Build report objects on demand (best-effort) so we can access required properties.
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

        # DisabledLinks/Enforcement are derived from GPOLinks.
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

        # Remaining fields are derived from GPO XML reports (best-effort).
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
                # Ignore individual GPO report failures.
            }
        }

        $gpoReports = @($gpoReportsById.Values)
    }

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

    $testResultMarkdown = "Active Directory GPOs have been analyzed for Apply Group Policy permissions. $noApplyAceCount out of $gpoCount GPO(s) are missing the required ACE.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
