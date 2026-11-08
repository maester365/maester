function Test-MtCaPlanHasOwner {
    <#
    .SYNOPSIS
    Checks that each Conditional Access policy plan records an accountable owner.

    .DESCRIPTION
    Reports plans with an empty owners collection as a metadata hygiene finding. Owners document responsibility;
    they do not grant edit rights or change enforcement. This read-only check does not resolve directory objects,
    detect deleted or disabled owners, inspect group membership, or require tenants to use plans.

    .EXAMPLE
    Test-MtCaPlanHasOwner

    Checks owner metadata on existing plans and skips when the tenant has no plans.
    #>
    [MaesterTest(
        Id = 'MT.1275',
        Title = 'Conditional Access policy plans have a recorded accountable owner.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'identity-lifecycle',
        ResourceType = 'Policy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'Graph',
        Permission = 'Graph:Scope:Policy.Read.All',
        License = 'AAD_PREMIUM',
        Lifecycle = 'Preview',
        Author = 'FiraSenax'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $plans = @(Get-MtConditionalAccessPolicyPlan -MetadataOnly)
    if ($plans.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return
    }
    $missing = @($plans | Where-Object {
            @($_.owners | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0
        })
    if ($missing.Count -gt 0) {
        Add-MtTestResultDetail -Result "Record an accountable owner for these Conditional Access policy plans. Owners are metadata and receive no edit permissions.`n`n%TestResult%" -GraphObjects $missing -GraphObjectType ConditionalAccessPlan
        return $false
    }
    Add-MtTestResultDetail -Result "Well done. All $($plans.Count) discovered Conditional Access policy plans record an owner. This validates metadata presence, not owner existence, activity or group membership."
    return $true
}
