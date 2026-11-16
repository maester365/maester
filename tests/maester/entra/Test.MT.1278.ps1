function Test-MT1278 {
    <#
        .SYNOPSIS
            Checks that the tenant has at least one Entra External ID user flow configured.
    #>
    [MaesterTest(
        Id                 = 'MT.1278',
        Title              = 'Should have at least one user flow configured',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'authentication',
        ResourceType       = 'UserFlow',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'Graph',
        Permission         = 'Graph:Scope:EventListener.Read.All',
        TenantType         = 'External',
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('UserFlows')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $userFlows = @((Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'identity/authenticationEventsFlows' -OutputType Hashtable).value)

    Add-MtTestResultDetail -Result "User flows configured: $($userFlows.Count)"

    return $userFlows.Count -gt 0
}
