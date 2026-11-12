function Test-MtCisaPowerPlatformContentSecurityPolicy {
    <#
    .SYNOPSIS
    Requests review of Content Security Policy enforcement for model-driven and canvas Power Apps.

    .DESCRIPTION
    ScubaGear audits MS.POWERPLATFORM.4.1v1 manually because the setting is stored per environment in Dataverse and has no
    tenant-level API. This check lists the tenant's environments and always requires investigation.

    .EXAMPLE
    Test-MtCisaPowerPlatformContentSecurityPolicy

    Lists the environments whose Content Security Policy settings need manual review.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformContentSecurityPolicy
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.4.1',
        Title              = 'Content Security Policy (CSP) SHALL be enforced for model-driven and canvas Power Apps.',
        Product            = 'power-platform',
        Feature            = 'power-apps',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1190',
        Control            = 'cisa-scuba:MS.POWERPLATFORM.4.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $environments = @(Get-MtPowerPlatformEnvironment)

    $resultMd = "| Environment | Type | Default |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($environment in $environments) {
        $resultMd += "| $($environment.DisplayName) | $($environment.EnvironmentType) | $($environment.IsDefault) |`n"
    }

    Add-MtTestResultDetail -Investigate -Result "ScubaGear audits this requirement manually. In each environment that uses Dataverse, confirm that **Enforce content security policy** is **On** for **Model-driven** and **Canvas** apps, and that reporting is enabled.`n`n$resultMd"
    return $false
}
