function Test-MtCheckMT1021 {
    <#
    .SYNOPSIS
    Security Defaults are enabled.

    .DESCRIPTION
    Checks that Security Defaults are enabled in a tenant without an Entra ID Premium licence. Tenants with Entra ID P1 or better are skipped, because they should use Conditional Access instead.
    #>
    [MaesterTest(
        Id = 'MT.1021',
        Title = 'Security Defaults are enabled.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('CA', 'Maester'),
        Service = 'Graph',
        Author = 'f-bader',
        Contributor = 'weyCC81'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if ($EntraIDPlan -ne 'Free') {
        Add-MtTestResultDetail -SkippedBecause LicensedEntraIDPremium
        return $null
    }

    $SecurityDefaults = Invoke-MtGraphRequest -RelativeUri 'policies/identitySecurityDefaultsEnforcementPolicy' -ApiVersion beta | Select-Object -ExpandProperty isEnabled

    if ($SecurityDefaults -eq $true) {
        $testResultMarkdown = "Well done. SecurityDefaults are On `n`n"
    } else {
        $testResultMarkdown = "SecurityDefaults are Off '$($SecurityDefaults)' `n`n"
    }
    $testDetailsMarkdown = 'You should enable SecurityDefaults or configure Conditional Access.'
    Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

    return ($SecurityDefaults -eq $true)
}
