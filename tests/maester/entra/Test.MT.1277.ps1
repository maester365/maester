function Test-MT1277 {
    <#
        .SYNOPSIS
            Checks that every Entra External ID user flow is linked to at least one application.
    #>
    [MaesterTest(
        Id                 = 'MT.1277',
        Title              = 'Each user flow must be linked to at least one application',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'applications',
        ResourceType       = 'UserFlow',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'Graph',
        Permission         = 'Graph:Scope:IdentityUserFlow.Read.All',
        TenantType         = 'External',
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('UserFlows')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $userFlows = @((Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'identity/authenticationEventsFlows' -OutputType Hashtable).value)

    $unlinkedFlows = @($userFlows | Where-Object {
        -not $_.conditions.applications.includeApplications
    })

    if ($unlinkedFlows.Count -gt 0) {
        $rows = $unlinkedFlows | ForEach-Object { "| $($_.displayName) | $($_.id) |" }
        $testResultMarkdown = "**Unlinked user flows ($($unlinkedFlows.Count) of $($userFlows.Count)):**`n`n" +
            "| Display name | Id |`n| --- | --- |`n" + ($rows -join "`n")
    } else {
        $testResultMarkdown = "All $($userFlows.Count) user flow(s) are linked to at least one application."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $unlinkedFlows.Count -eq 0
}
