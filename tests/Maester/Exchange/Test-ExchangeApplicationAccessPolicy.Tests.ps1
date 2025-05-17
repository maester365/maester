Describe "Maester/Exchange" -Tag "Maester", "Exchange", "Security", "MT.1060" {
    BeforeAll {
        # Skip all tests if Exchange Online or Graph is not connected
        if (-not (Test-MtConnection ExchangeOnline)) {
            Set-ItResult -Skipped -Because "Exchange Online is not connected"
        }
        if (-not (Test-MtConnection Graph)) {
            Set-ItResult -Skipped -Because "Graph API is not connected"
        }
    }

    It "MT.1060: Ensure Exchange Application Access Policy is configured" -Tag "MT.1060", "ApplicationAccess" {
        # Define Exchange permissions that require app access policies (from Microsoft docs)
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

        foreach ($app in $principalsWithExchangePerms) {
            $hasPolicy = $appAccessPolicies.AppId -contains $app.AppId
            $policyStatus = if ($hasPolicy) { "✅ Yes" } else { "❌ No" }
            $testResultMarkdown += "| $($app.Name) | $($app.AppId) | $($app.Permissions) | $policyStatus |`n"
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

Best practices:
- Create policies to restrict application access to only required mailboxes
- Ensure every application with Exchange permissions has an access policy

Learn more: https://learn.microsoft.com/graph/auth-limit-mailbox-access
"@

        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown

        # Test should fail if any apps are missing policies
        $missingPolicies = $principalsWithExchangePerms | Where-Object { $appAccessPolicies.AppId -notcontains $_.AppId }
        $missingPolicies.Count | Should -Be 0 -Because "all applications with Exchange permissions should have an access policy configured"
    }
}