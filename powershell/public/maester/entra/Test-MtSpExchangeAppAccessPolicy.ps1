<#
.SYNOPSIS
    Check if service principals with Exchange permissions have application access policies configured.

.DESCRIPTION
    Service principals with Exchange permissions can access all mailboxes by default. This test verifies that proper access policies are in place.

.EXAMPLE
    Test-MtSpExchangeAppAccessPolicy

    Returns true if all service principals with Exchange permissions have access policies configured.

.LINK
    https://maester.dev/docs/commands/Test-MtSpExchangeAppAccessPolicy
#>
function Test-MtSpExchangeAppAccessPolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-MtSpExchangeAppAccessPolicy"

    if (-not (Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        # Note: If you make any changes to this list, please keep it in sync
        # with the markdown file Test-MtSpExchangeAppAccessPolicy.md
        $exchangePermissions = @(
            "Mail.Read", "Mail.ReadBasic", "Mail.ReadBasic.All", "Mail.ReadWrite", "Mail.Send",
            "MailboxSettings.Read", "MailboxSettings.ReadWrite",
            "Calendars.Read", "Calendars.ReadWrite",
            "Contacts.Read", "Contacts.ReadWrite"
        )

        # Get service principals with Exchange permissions
        $msGraph = Invoke-MtGraphRequest -RelativeUri "servicePrincipals" -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
        $availablePermissions = $msGraph.AppRoles | Select-Object Id, Value

        $servicePrincipals = Invoke-MtGraphRequest -RelativeUri "servicePrincipals"
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
                    Permissions = $permissions -join ", "
                }
            }
        }

        # Get application access policies
        $appAccessPolicies = Get-ApplicationAccessPolicy

        # Prepare result table showing all apps with Exchange permissions
        $detailMarkdown = "### Applications with Exchange Permissions`n`n"
        $detailMarkdown += "| Application | Permissions | Access Policy? |`n"
        $detailMarkdown += "| --- | --- | --- |`n"

        $missingPolicies = @()
        foreach ($sp in $principalsWithExchangePerms) {
            $hasPolicy = $appAccessPolicies.AppId -contains $sp.AppId
            $policyStatus = if ($hasPolicy) { "✅ Yes" } else { "❌ No" }
            $filteredPermissions = $sp.Permissions -split ', ' | Where-Object { $_ -in $exchangePermissions }
            $portalLink = Get-MtLinkServicePrincipal -ServicePrincipal $sp -Blade Permissions
            $detailMarkdown += "| $portalLink | $($filteredPermissions -join ', ') | $policyStatus |`n"

            if (-not $hasPolicy) {
                $missingPolicies += $sp
            }
        }

        $invalidCount = ($missingPolicies | Measure-Object).Count
        $result = $invalidCount -eq 0

        if ($result) {
            $testResultMarkdown = "Well done. We did not find any applications with tenant-wide Exchange permissions to all mailboxes."
        } else {
            $testResultMarkdown = "Found **$invalidCount** applications with tenant-wide access to all Exchange mailboxes."
        }
        $testResultMarkdown += "`n`n" + $detailMarkdown

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    }

    return $result
}