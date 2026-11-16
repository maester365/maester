function Test-MT1280 {
    <#
        .SYNOPSIS
            Checks that every application linked to an Entra External ID user flow has the
            Microsoft Graph User.Read delegated permission granted with admin consent.
    #>
    [MaesterTest(
        Id                 = 'MT.1280',
        Title              = 'Should have User.Read granted with admin consent for linked applications',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'applications',
        ResourceType       = 'UserFlow',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'Graph',
        Permission         = ('Graph:Scope:EventListener.Read.All', 'Graph:Scope:Application.Read.All'),
        TenantType         = 'External',
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('UserFlows')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Microsoft Graph's own well-known appId; resolve its service principal once.
    $graphSp = (Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'" -OutputType Hashtable).value | Select-Object -First 1

    $userFlows = @((Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'identity/authenticationEventsFlows' -OutputType Hashtable).value)

    $linkedAppResults = @()
    foreach ($flow in $userFlows) {
        $linkedApps = @($flow.conditions.applications.includeApplications)
        foreach ($linkedApp in $linkedApps) {
            # includeApplications entries may be plain appId strings, or objects carrying the appId
            # under a property such as appId/id/applicationId depending on the Graph response shape.
            $appId = if ($linkedApp -is [string]) {
                $linkedApp
            } elseif ($linkedApp -is [System.Collections.IDictionary]) {
                @($linkedApp.appId, $linkedApp.id, $linkedApp.applicationId) | Where-Object { $_ } | Select-Object -First 1
            } else {
                $linkedApp.appId
            }

            if (-not $appId) { continue }

            $sp = $null
            $app = $null
            $grants = @()
            try {
                $sp = (Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "servicePrincipals?`$filter=appId eq '$appId'" -OutputType Hashtable).value | Select-Object -First 1
                if ($sp -and $graphSp) {
                    $grants = @((Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "servicePrincipals/$($sp.id)/oauth2PermissionGrants" -OutputType Hashtable).value |
                        Where-Object { $_.resourceId -eq $graphSp.id })
                }
            } catch {
                Write-Verbose "Failed to resolve service principal/grants for appId '$appId' - $($_.Exception.Message)"
            }

            # Service principal display names are occasionally blank; fall back to the app registration object.
            if (-not $sp -or -not $sp.displayName) {
                try {
                    $app = (Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "applications?`$filter=appId eq '$appId'" -OutputType Hashtable).value | Select-Object -First 1
                } catch {
                    Write-Verbose "Failed to resolve application registration for appId '$appId' - $($_.Exception.Message)"
                }
            }

            $appDisplayName = if ($sp -and $sp.displayName) { $sp.displayName } elseif ($app -and $app.displayName) { $app.displayName } else { $null }
            $appName = if ($appDisplayName) { $appDisplayName } else { "$appId (name unavailable)" }

            $adminConsentedUserReadGrant = $grants | Where-Object {
                $_.consentType -eq 'AllPrincipals' -and ($_.scope -split '\s+') -contains 'User.Read'
            }

            $linkedAppResults += [pscustomobject]@{
                FlowDisplayName = $flow.displayName
                AppName         = $appName
                AppId           = $appId
                SpFound         = [bool]$sp
                Grants          = $grants
                HasGrant        = [bool]$adminConsentedUserReadGrant
            }
        }
    }

    $failingResults = @($linkedAppResults | Where-Object { -not $_.SpFound -or -not $_.HasGrant })

    if ($failingResults.Count -gt 0) {
        $rows = $failingResults | ForEach-Object {
            if (-not $_.SpFound) {
                $grantsSummary = '*(service principal not found)*'
            } else {
                $scopesSummary = ($_.Grants | ForEach-Object { "$($_.scope) (consentType: $($_.consentType))" }) -join '; '
                $grantsSummary = if ($scopesSummary) { $scopesSummary } else { '*(none)*' }
            }
            "| $($_.FlowDisplayName) | $($_.AppName) | $($_.AppId) | $grantsSummary |"
        }
        $testResultMarkdown = "**Linked applications missing User.Read with admin consent ($($failingResults.Count) of $($linkedAppResults.Count)):**`n`n" +
            "| User flow | Application | Application (appId) | Delegated Graph grants |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    } else {
        $testResultMarkdown = "All $($linkedAppResults.Count) linked application(s) have Microsoft Graph User.Read granted with admin consent."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $failingResults.Count -eq 0
}
