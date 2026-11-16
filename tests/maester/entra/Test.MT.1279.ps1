function Test-MT1279 {
    <#
        .SYNOPSIS
            Checks that every custom identity provider configured in the tenant is linked
            to at least one Entra External ID user flow.
    #>
    [MaesterTest(
        Id                 = 'MT.1279',
        Title              = 'Should not have custom OIDC identity providers unlinked from any user flow',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'authentication',
        ResourceType       = 'UserFlow',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'Graph',
        Permission         = ('Graph:Scope:EventListener.Read.All', 'Graph:Scope:IdentityProvider.Read.All'),
        TenantType         = 'External',
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('UserFlows')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Built-in/social identity providers are not "custom" and are excluded. SAML/WS-Fed
    # identity providers are not exposed via this API for Entra External ID (CIAM) tenants,
    # so only custom OpenID Connect providers are evaluated here.
    $builtInProviderTypes = @('Google', 'Facebook', 'Amazon', 'Microsoft', 'LinkedIn', 'EmailOTP', 'EmailPassword', 'Apple', 'GitHub', 'QQ', 'WeChat', 'Weibo')

    $allProviders = @((Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri 'identity/identityProviders' -OutputType Hashtable).value)
    $customProviders = @($allProviders | Where-Object { $_.identityProviderType -notin $builtInProviderTypes })

    $userFlows = @((Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'identity/authenticationEventsFlows' -OutputType Hashtable).value)

    $linkedProviderIds = @($userFlows | ForEach-Object {
            $_.onAuthenticationMethodLoadStart.identityProviders | ForEach-Object { $_.id }
        }) | Where-Object { $_ } | Select-Object -Unique

    $unlinkedProviders = @($customProviders | Where-Object { $_.id -notin $linkedProviderIds })

    if ($customProviders.Count -eq 0) {
        $testResultMarkdown = "No custom OIDC identity providers found in this tenant."
    } elseif ($unlinkedProviders.Count -eq 0) {
        $testResultMarkdown = "All $($customProviders.Count) custom OIDC identity provider(s) are linked to at least one user flow."
    } else {
        $rows = $unlinkedProviders | ForEach-Object { "| $($_.displayName) | $($_.identityProviderType) | $($_.id) |" }
        $testResultMarkdown = "**Unlinked custom OIDC identity providers ($($unlinkedProviders.Count) of $($customProviders.Count)):**`n`n" +
            "| Display name | Type | Id |`n| --- | --- | --- |`n" + ($rows -join "`n")
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $unlinkedProviders.Count -eq 0
}
