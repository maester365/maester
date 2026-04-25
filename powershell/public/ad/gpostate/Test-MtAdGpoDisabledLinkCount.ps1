<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoDisabledLinkCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that have disabled GPO links.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes the GPO link configuration to count GPOs that have disabled links.

    .EXAMPLE
    Test-MtAdGpoDisabledLinkCount

    Returns $true if GPO link data is accessible, $false otherwise.
    The test result includes the number of GPOs with disabled links.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDisabledLinkCount
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

        foreach ($link in @($gpoState.GPOLinks | Where-Object { $null -ne $_ })) {
            if ($null -eq $link.gPLink) { continue }
            $linkEntries = ($link.gPLink -split '\]' | Where-Object { $_ -match 'LDAP://' })
            foreach ($entry in $linkEntries) {
                if ($entry -notmatch 'CN=\\{?([0-9a-fA-F-]{36})\\}?,CN=policies' ) { continue }
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

        # Best-effort: populate remaining properties by reading the GPO XML report.
        foreach ($gpo in $gpos) {
            $guid = [string]$gpo.Id
            $reportObj = $gpoReportsById[$guid]
            if ($null -eq $reportObj) { continue }
            try {
                $xmlText = Get-GPOReport -Guid $guid -ReportType Xml -ErrorAction Stop
                if ($xmlText -match '(?i)version\s+mismatch') { $reportObj.HasVersionMismatch = $true }
                if ($xmlText -match '(?i)cpassword') {
                    $reportObj.CpasswordFound = $true
                    $reportObj.DefaultPasswordFound = $true
                }
                if ($xmlText -match '(?i)Apply\s+Group\s+Policy') { $reportObj.HasApplyGroupPolicyAce = $true }
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
    $disabledCount = @($gpoReportsArray | Where-Object { [int]$_.DisabledLinks -gt 0 }).Count
    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with disabled links | $disabledCount |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for disabled links. $disabledCount out of $totalCount GPO(s) have disabled link(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
