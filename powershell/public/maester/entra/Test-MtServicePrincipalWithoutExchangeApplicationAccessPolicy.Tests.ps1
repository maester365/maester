<#
.SYNOPSIS
    Check if service principals with Exchange permissions have application access policies configured.

.DESCRIPTION
    Service principals with Exchange permissions can access all mailboxes by default. This test verifies that proper access policies are in place.

.EXAMPLE
    Test-MtServicePrincipalWithoutExchangeApplicationAccessPolicy

    Returns true if all service principals with Exchange permissions have access policies configured.

.LINK
    https://maester.dev/docs/commands/Test-MtServicePrincipalWithoutExchangeApplicationAccessPolicy
#>
function Test-MtServicePrincipalWithoutExchangeApplicationAccessPolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    if (-not (Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchangeOnline
        return $null
    }

    try {
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
                    Name = $sp.DisplayName
                    AppId = $sp.AppId
                    Permissions = $permissions -join ", "
                }
            }
        }

        # Get application access policies
        $appAccessPolicies = Get-ApplicationAccessPolicy

        # Prepare result table showing all apps with Exchange permissions
        $testResultMarkdown = "### Applications with Exchange Permissions`n`n"
        $testResultMarkdown += "| Application Name | AppId | Permissions | Has Access Policy |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"

        $missingPolicies = @()
        foreach ($app in $principalsWithExchangePerms) {
            $hasPolicy = $appAccessPolicies.AppId -contains $app.AppId
            $policyStatus = if ($hasPolicy) { "✅ Yes" } else { "❌ No" }
            $filteredPermissions = $app.Permissions -split ', ' | Where-Object { $_ -in $exchangePermissions }
            $testResultMarkdown += "| $($app.Name) | $($app.AppId) | $($filteredPermissions -join ', ') | $policyStatus |`n"

            if (-not $hasPolicy) {
                $missingPolicies += $app
            }
        }

        $testDetailsMarkdown = @"
Application access policies in Exchange Online help you control which applications can access which mailboxes.
Without these policies, applications with Exchange permissions can access all mailboxes in your organization.

Microsoft Graph permissions that should be secured by application access policies:
- Mail.Read
- Mail.ReadBasic
- Mail.ReadBasic.All
- Mail.ReadWrite
- Mail.Send
- MailboxSettings.Read
- MailboxSettings.ReadWrite
- Calendars.Read
- Calendars.ReadWrite
- Contacts.Read
- Contacts.ReadWrite

See https://learn.microsoft.com/graph/auth-limit-mailbox-access
"@

        $return = $missingPolicies.Count -eq 0
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown -Severity 'Medium'
    }
    catch {
        $return = $false
        Write-Error $_.Exception.Message
    }
    return $return
}