function Test-MtCisaPowerPlatformTenantIsolationAllowlist {
    <#
    .SYNOPSIS
    Requests review of the Power Platform tenant isolation inbound and outbound allowlist.

    .DESCRIPTION
    ScubaGear audits MS.POWERPLATFORM.3.2v1 manually. Whether an allowlist is needed, and which tenants it should name,
    depends on the organization's cross-tenant collaboration needs. This check lists the configured exceptions and
    always requires investigation.

    .EXAMPLE
    Test-MtCisaPowerPlatformTenantIsolationAllowlist

    Lists the tenant isolation exceptions for manual review.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformTenantIsolationAllowlist
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.3.2',
        Title              = 'An inbound/outbound connection allowlist SHOULD be configured.',
        Product            = 'power-platform',
        Feature            = 'tenant-isolation',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'cisa-scuba:MS.POWERPLATFORM.3.2',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtPowerPlatformTenantIsolation
    $allowedTenants = @()
    if ($null -ne $policy -and $null -ne $policy.properties -and $null -ne $policy.properties.PSObject.Properties['allowedTenants']) {
        $allowedTenants = @($policy.properties.allowedTenants | Where-Object { $_ })
    }

    $resultMd = "| Tenant | Inbound | Outbound |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($allowedTenant in $allowedTenants) {
        $direction = $allowedTenant.direction
        $inbound = if ($null -ne $direction) { $direction.inbound } else { 'Unknown' }
        $outbound = if ($null -ne $direction) { $direction.outbound } else { 'Unknown' }
        $resultMd += "| $($allowedTenant.tenantId) | $inbound | $outbound |`n"
    }

    $summary = if ($allowedTenants.Count -gt 0) {
        "$($allowedTenants.Count) tenant isolation exception(s) are configured."
    }
    else {
        'No tenant isolation exceptions are configured. An empty allowlist is acceptable when the organization has no need for cross-tenant collaboration.'
    }

    Add-MtTestResultDetail -Investigate -Result "ScubaGear audits this requirement manually. Confirm that the allowlist matches the organization's cross-tenant collaboration needs.`n`n$summary`n`n$resultMd"
    return $false
}
