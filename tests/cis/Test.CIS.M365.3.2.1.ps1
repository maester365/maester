function Test-MtCisDlpPoliciesEnabled {
    <#
    .SYNOPSIS
        Checks that at least one data loss prevention policy is on and covers a Microsoft 365 workload.

    .DESCRIPTION
        Checks that at least one data loss prevention policy that is not a Copilot policy is turned on and applies to all locations in Exchange, SharePoint, OneDrive or Teams.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.1, L1)

    .EXAMPLE
        Test-MtCisDlpPoliciesEnabled

        Returns true if an enabled DLP policy covers a Microsoft 365 location.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.3.2.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.2.1',
        Title = 'Ensure DLP policies are enabled',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Control = ('cis-m365:3.2.1', 'nist-800-53-r5:AC-4'),
        Service = 'SecurityCompliance',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting data loss prevention policies...'
    $policies = @(Get-MtExo -Request DlpCompliancePolicy | Where-Object { $_.EnforcementPlanes -notcontains 'CopilotExperiences' })

    $report = foreach ($policy in $policies) {
        $locations = [ordered]@{
            Exchange = $policy.ExchangeLocation.ImmutableIdentity -eq 'All'
            SharePoint = $policy.SharePointLocation.ImmutableIdentity -eq 'All'
            OneDrive = $policy.OneDriveLocation.ImmutableIdentity -eq 'All'
            Teams = $policy.TeamsLocation.ImmutableIdentity -eq 'All'
        }
        $covered = @($locations.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Locations = if ($covered.Count -gt 0) { $covered -join ', ' } else { 'None' }
            Pass = $policy.Mode -eq 'Enable' -and $covered.Count -gt 0
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -ge 1

    $passText = 'At least one data loss prevention policy is enabled and covers a Microsoft 365 location.'
    $failText = if ($policies.Count -eq 0) { 'No data loss prevention policy was found.' } else { 'No data loss prevention policy is both enabled and applied to all of a Microsoft 365 location.' }

    $resultMd = "| Policy | Mode | Locations covered | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.Mode) | $($row.Locations) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
