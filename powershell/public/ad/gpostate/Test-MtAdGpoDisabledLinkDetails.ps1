<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoDisabledLinkDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs with disabled GPO links.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes the GPO link configuration to return a markdown table of GPOs whose
    link(s) are disabled.

    .EXAMPLE
    Test-MtAdGpoDisabledLinkDetails

    Returns $true if GPO link data is accessible, $false otherwise.
    The test result includes a markdown table listing GPOs with disabled link(s).

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDisabledLinkDetails
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
                if ($entry -notmatch 'CN=\\{?([0-9a-fA-F-]{36})\\}?,CN=policies') { continue }
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
                if ($xmlText -match '(?i)Apply\s+Group\s+Policy') { $reportObj.HasApplyGroupPolicyAce = $true }
                if ($xmlText -match '(?i)version\s+mismatch') { $reportObj.HasVersionMismatch = $true }
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
    $disabled = $gpoReportsArray | Where-Object { [int]$_.DisabledLinks -gt 0 }
    $disabledCount = @($disabled).Count

    $testResult = $true

    $table = "| GPO Name | Id (Guid) | DisabledLinks | Enforcement |`n"
    $table += '| --- | --- | --- | --- |' + "`n"

    foreach ($report in (@($disabled) | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\\|', '\\&#124;'

        # Best-effort Id column: some scenarios may not have it on the report object.
        $id = ''
        if ($null -ne $report.Id) { $id = [string]$report.Id }
        $id = $id -replace '\\|', '\\&#124;'

        $disabledLinks = [int]$report.DisabledLinks
        $enforcement = [int]$report.Enforcement
        $table += "| $name | $id | $disabledLinks | $enforcement |`n"
    }

    $recommendation = if ($disabledCount -gt 0) {
        "GPO disabled link details were returned ($disabledCount). Review these GPO links to ensure they are still intended."
    }
    else {
        '✅ No GPOs with disabled link configuration were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
