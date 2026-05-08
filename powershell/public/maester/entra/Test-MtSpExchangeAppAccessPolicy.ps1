function Test-MtSpExchangeAppAccessPolicy {
    <#
    .SYNOPSIS
    Check if service principals with Exchange permissions have application access policies configured.

    .DESCRIPTION
    Service principals with Exchange permissions can access all mailboxes by default. This test verifies that proper access policies are in place.

    .EXAMPLE
    Test-MtSpExchangeAppAccessPolicy

    Returns true if all service principals with Exchange permissions have access policies configured

    .LINK
    https://maester.dev/docs/commands/Test-MtSpExchangeAppAccessPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Running Test-MtSpExchangeAppAccessPolicy'

    if (-not (Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        # Note: If you make any changes to this list, please keep it in sync
        # with the markdown file Test-MtSpExchangeAppAccessPolicy.md
        $exchangePermissions = @(
            'Mail.Read', 'Mail.ReadBasic', 'Mail.ReadBasic.All', 'Mail.ReadWrite', 'Mail.Send',
            'MailboxSettings.Read', 'MailboxSettings.ReadWrite',
            'Calendars.Read', 'Calendars.ReadWrite',
            'Contacts.Read', 'Contacts.ReadWrite'
        )

        # Get service principals with Exchange permissions
        $msGraph = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
        $availablePermissions = $msGraph.AppRoles | Select-Object Id, Value

        $servicePrincipals = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals'
        $principalsWithExchangePerms = $servicePrincipals | ForEach-Object {
            $sp = $_
            $appRoles = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$($sp.Id)/appRoleAssignments"
            $permissions = $appRoles.AppRoleId | ForEach-Object {
                $roleId = $_
                ($availablePermissions | Where-Object { $_.Id -eq $roleId }).Value
            }

            if ($permissions | Where-Object { $_ -in $exchangePermissions }) {
                [PSCustomObject]@{
                    Id          = $sp.Id
                    DisplayName = $sp.DisplayName
                    AppId       = $sp.AppId
                    Permissions = $permissions -join ', '
                }
            }
        }

        # Get application access policies
        try {
            $appAccessPolicies = Get-ApplicationAccessPolicy -ErrorAction Stop
        } catch {
            if ($_.Exception.Message -like "*couldn't be found*") {
                Write-Verbose -Message 'Test-MtSpExchangeAppAccessPolicy: No application access policies were found.'
                $appAccessPolicies = $null
            } else {
                throw
            }
        }

        $missingPolicies = @()
        $appsWithPolicies = @()
        foreach ($sp in $principalsWithExchangePerms) {
            $hasPolicy = $appAccessPolicies.AppId -contains $sp.AppId
            $filteredPermissions = $sp.Permissions -split ', ' | Where-Object { $_ -in $exchangePermissions }
            $appRecord = [PSCustomObject]@{
                Id          = $sp.Id
                DisplayName = $sp.DisplayName
                AppId       = $sp.AppId
                Permissions = $filteredPermissions -join ', '
            }

            if (-not $hasPolicy) {
                $missingPolicies += $appRecord
            } else {
                $appsWithPolicies += $appRecord
            }
        }

        $appsWithExchangePermissionsCount = ($principalsWithExchangePerms | Measure-Object).Count
        $invalidCount = ($missingPolicies | Measure-Object).Count
        $result = $invalidCount -eq 0

        if ($appsWithExchangePermissionsCount -eq 0) {
            $testResultMarkdown = 'Well done. No applications with Exchange permissions were found.'
        } elseif ($result) {
            $testResultMarkdown = "Well done. All **$appsWithExchangePermissionsCount** applications with Exchange permissions have Exchange application access policies configured."
        } else {
            $testResultMarkdown = "Found **$appsWithExchangePermissionsCount** applications with Exchange permissions. **$invalidCount** application(s) do not have Exchange application access policies configured."

            $missingPoliciesMarkdown = "`n`n### Applications Missing Exchange Application Access Policies`n`n"
            $missingPoliciesMarkdown += "| Application | Application ID | Exchange Permissions |`n"
            $missingPoliciesMarkdown += "| --- | --- | --- |`n"

            foreach ($app in ($missingPolicies | Sort-Object -Property DisplayName)) {
                $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $app -Blade Permissions
                $missingPoliciesMarkdown += "| $portalLink | $($app.AppId) | $($app.Permissions) |`n"
            }

            $testResultMarkdown += $missingPoliciesMarkdown
        }

        if ($appsWithPolicies.Count -gt 0 -and $invalidCount -gt 0) {
            $testResultMarkdown += "`n`n**Applications with access policies configured:** $($appsWithPolicies.Count)"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
