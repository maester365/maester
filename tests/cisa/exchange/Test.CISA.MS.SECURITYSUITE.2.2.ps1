function Test-MtCisaOwnedDomainImpersonationProtection {
    <#
    .SYNOPSIS
    Checks domain impersonation protection for agency-owned domains.

    .DESCRIPTION
    Domain impersonation protection SHOULD be enabled for domains owned by the agency and apply to all recipients.

    .EXAMPLE
    Test-MtCisaOwnedDomainImpersonationProtection

    Returns true when an enabled policy applying to all recipients protects owned domains with an acceptable action.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaOwnedDomainImpersonationProtection
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.2.2',
        Title = 'Domain impersonation protection SHOULD be enabled for domains owned by the agency.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-phishing',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.2.2',
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtCisaEffectiveAntiPhishPolicy)
    $allowedActions = @('MoveToJmf', 'Quarantine', 'Redirect', 'Delete')
    $compliantPolicies = @(
        $policies | Where-Object {
            $_.EnableOrganizationDomainsProtection -eq $true -and
            $_.TargetedDomainProtectionAction -in $allowedActions
        }
    )
    $testResult = $compliantPolicies.Count -gt 0

    $result = "| Effective policy | Owned-domain protection | Action | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($policy in $policies | Sort-Object -Property Identity) {
        $enabled = $policy.EnableOrganizationDomainsProtection -eq $true
        $action = if ($policy.TargetedDomainProtectionAction) { $policy.TargetedDomainProtectionAction } else { 'Not configured' }
        $status = if ($enabled -and $policy.TargetedDomainProtectionAction -in $allowedActions) { '✅ Pass' } else { '❌ Fail' }
        $result += "| $($policy.Identity) | $(if ($enabled) { 'Enabled' } else { 'Disabled' }) | $action | $status |`n"
    }

    if ($testResult) {
        $message = "Well done. An enabled anti-phishing policy applying to all recipients protects agency-owned domains.`n`n%TestResult%"
    } else {
        $message = "Enable owned-domain impersonation protection with an action that redirects, moves to Junk Email, quarantines, or deletes the message in an anti-phishing policy that applies to all recipients.`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
