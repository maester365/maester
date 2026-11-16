function Test-MT1281 {
    <#
        .SYNOPSIS
            Checks that applications linked to an Entra External ID user flow do not have
            expired or soon-to-expire client secrets/certificates.
    #>
    [MaesterTest(
        Id                 = 'MT.1281',
        Title              = 'Should not have expired or expiring credentials for linked applications',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'applications',
        ResourceType       = 'UserFlow',
        Severity           = 'High',
        UserImpact         = 'High',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'Graph',
        Permission         = ('Graph:Scope:IdentityUserFlow.Read.All', 'Graph:Scope:Application.Read.All'),
        TenantType         = 'External',
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('UserFlows')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # How many days ahead of expiry a still-valid credential is flagged as "expiring soon".
        [ValidateRange(1, 365)]
        [int] $ExpiryWarningDays = 30
    )

    $userFlows = @((Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'identity/authenticationEventsFlows' -OutputType Hashtable).value)

    $now = Get-Date
    $warningCutoff = $now.AddDays($ExpiryWarningDays)

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

            $app = $null
            try {
                $app = (Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "applications?`$filter=appId eq '$appId'" -OutputType Hashtable).value | Select-Object -First 1
            } catch {
                Write-Verbose "Failed to resolve application registration for appId '$appId' - $($_.Exception.Message)"
            }

            $appName = if ($app -and $app.displayName) { $app.displayName } else { "$appId (name unavailable)" }

            # A single certificate is listed once per usage (Sign and Verify). Both entries share the
            # thumbprint in customKeyIdentifier, so evaluate each certificate only once. Secrets have
            # no thumbprint and are always distinct.
            $certificates = @($app.keyCredentials |
                    Where-Object { $_ -and $_.endDateTime } |
                    Group-Object -Property { if ($_.customKeyIdentifier) { $_.customKeyIdentifier } else { $_.keyId } } |
                    ForEach-Object { $_.Group | Select-Object -First 1 })

            $credentials = @()
            $credentials += @($app.passwordCredentials) | Where-Object { $_ -and $_.endDateTime } | ForEach-Object {
                [pscustomobject]@{ Type = 'Secret'; DisplayName = $_.displayName; EndDateTime = [datetime]$_.endDateTime }
            }
            $credentials += $certificates | ForEach-Object {
                [pscustomobject]@{ Type = 'Certificate'; DisplayName = $_.displayName; EndDateTime = [datetime]$_.endDateTime }
            }

            $expired = @($credentials | Where-Object { $_.EndDateTime -lt $now })
            $expiringSoon = @($credentials | Where-Object { $_.EndDateTime -ge $now -and $_.EndDateTime -le $warningCutoff })

            $linkedAppResults += [pscustomobject]@{
                FlowDisplayName = $flow.displayName
                AppName         = $appName
                AppId           = $appId
                AppFound        = [bool]$app
                Credentials     = $credentials
                Expired         = $expired
                ExpiringSoon    = $expiringSoon
            }
        }
    }

    $failingResults = @($linkedAppResults | Where-Object { -not $_.AppFound -or $_.Expired.Count -gt 0 -or $_.ExpiringSoon.Count -gt 0 })

    if ($failingResults.Count -gt 0) {
        $rows = $failingResults | ForEach-Object {
            if (-not $_.AppFound) {
                $credentialsSummary = '*(application registration not found)*'
            } elseif ($_.Credentials.Count -eq 0) {
                $credentialsSummary = '*(no secrets or certificates configured)*'
            } else {
                $credentialsSummary = ($_.Credentials | Sort-Object EndDateTime | ForEach-Object {
                        $status = if ($_.EndDateTime -lt $now) { 'Expired' } elseif ($_.EndDateTime -le $warningCutoff) { 'Expiring soon' } else { 'OK' }
                        "$($_.Type) '$($_.DisplayName)' expires $($_.EndDateTime.ToString('yyyy-MM-dd')) ($status)"
                    }) -join '; '
            }
            "| $($_.FlowDisplayName) | $($_.AppName) | $($_.AppId) | $credentialsSummary |"
        }
        $testResultMarkdown = "**Linked applications with expired/expiring credentials ($($failingResults.Count) of $($linkedAppResults.Count)):**`n`n" +
            "| User flow | Application | Application (appId) | Credentials |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    } else {
        $testResultMarkdown = "All $($linkedAppResults.Count) linked application(s) have valid, non-expiring credentials."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $failingResults.Count -eq 0
}
