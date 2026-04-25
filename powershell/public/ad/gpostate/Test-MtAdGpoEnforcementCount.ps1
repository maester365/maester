<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoEnforcementCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that have enforced GPO links.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then analyzes the GPO link configuration to count GPOs that have enforced link(s).

    .EXAMPLE
    Test-MtAdGpoEnforcementCount

    Returns $true if GPO link data is accessible, $false otherwise.
    The test result includes the number of GPOs with enforced links.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoEnforcementCount
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

        $gpoReports = @($gpoReportsById.Values)
    }

    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $totalCount = $gpoReportsArray.Count
    $enforcedCount = @($gpoReportsArray | Where-Object { [int]$_.Enforcement -gt 0 }).Count

    $testResult = $true
    $enforcedPercentage = if ($totalCount -gt 0) { [Math]::Round(($enforcedCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with enforced links | $enforcedCount |`n"
    $result += "| Enforced ratio | $enforcedPercentage% |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for enforced links. $enforcedCount out of $totalCount GPO(s) have enforced link(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
