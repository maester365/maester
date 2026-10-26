function Test-MtCisTeamsTrialTenantsBlocked {
    <#
    .SYNOPSIS
        Ensure the organization cannot communicate with accounts in trial Teams tenants

    .DESCRIPTION
        Checks that the tenant federation configuration blocks communication with accounts in trial Teams
        tenants.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.2.4, L1)

    .EXAMPLE
        Test-MtCisTeamsTrialTenantsBlocked

        Returns true if communication with trial Teams tenants is blocked.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsTrialTenantsBlocked
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.2.4',
        Title = 'Ensure the organization cannot communicate with accounts in trial Teams tenants',
        Product = 'teams',
        Feature = 'external-access',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.2.4', 'nist-800-53-r5:AC-20'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsTrialTenantsBlocked: Checking the trial tenant setting'
    $federation = Get-CsTenantFederationConfiguration
    $setting = $federation.ExternalAccessWithTrialTenants
    $testResult = $setting -eq 'Blocked'

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Communication with accounts in trial Teams tenants is blocked.`n`n"
    } else {
        "The organization can communicate with accounts in trial Teams tenants.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| ExternalAccessWithTrialTenants | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
