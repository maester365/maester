Controls whether users can create agent identity blueprints and their associated principals through the default user role. Blueprint creators become owners and can create agent identities for their blueprints. Allowing creation does not itself grant access to organizational data.

Restrict agent identity blueprint creation through the default user role. Use designated Agent ID roles to govern creation. Blueprint creation and permission grants are separate controls; restricting creation does not disable existing blueprints or agent identities.

#### Test script
```
https://graph.microsoft.com/beta/policies/authorizationPolicy
.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints -eq 'false'
```

#### Remediation action

In Microsoft Entra user settings, set Users can create agent blueprints to No. Review the impact on approved agent development workflows. See [Microsoft Learn - Create an agent identity blueprint](https://learn.microsoft.com/entra/agent-id/create-blueprint).

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authorizationPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [authorizationPolicy resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/authorizationpolicy?view=graph-rest-beta)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings)



<!--- Results --->
%TestResult%
