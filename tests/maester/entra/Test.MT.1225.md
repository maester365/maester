## Description

Checks that default users, meaning users who hold no built-in or custom Entra role, cannot create agent identity blueprints.

## Why This Matters

An agent identity blueprint is the template that agent identities get their credentials from. It works like an app registration built for agents: it holds the credentials, and every agent identity created from it authenticates through it.

The user who creates a blueprint becomes its owner. An owner can manage the credentials, change the configuration, add more owners and create agent identities from the blueprint, without holding any Agent ID role. Turning the setting off later does not take anything away from users who already created a blueprint.

Microsoft is adding a default user role setting, shown in the Entra admin center as **Users can register agent identity blueprints**. The announcement, message center item MC1506733, calls it "Users can create agent blueprints". It is on by default. From 4 November 2026, with the rollout expected to finish in late November, users without a built-in or custom Entra role can create blueprints unless an administrator turns the setting off. When it is off, only administrators and users with the **Agent ID Developer** or **Agent ID Administrator** role can create them.

Creating a blueprint does not grant access to company data by itself. What an agent can reach depends on the permissions that are consented to. Delegated permissions let the agent act as the signed-in user, and your user consent settings decide whether users can approve them themselves. Application permissions always need admin consent. The user consent configuration therefore decides how much risk a user-created agent carries.

The setting is independent of **Users can register applications**. Restricting application registrations does not restrict agent blueprints.

This test reads `defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints` from the authorization policy. The property is only returned by the Microsoft Graph beta endpoint and is not yet documented there, so its name may change before the rollout completes. The test is skipped when the tenant does not return it.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Users** > [**User settings**](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/).
3. Under **Default user role permissions**, set **Users can register agent identity blueprints** to **No**, then save. You can set it before the rollout reaches your tenant, and it takes effect when it does.

### Related links

* [MC1506733 - Review who can create agents in Microsoft Entra | Message center archive](https://mc.merill.net/message/MC1506733)
* [Create an agent identity blueprint | Microsoft Learn](https://learn.microsoft.com/entra/agent-id/create-blueprint)
* [Agent ID roles | Microsoft Learn](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference)
* [Microsoft Entra lets users create agent blueprints by default | LazyAdmin](https://lazyadmin.nl/office-365/microsoft-entra-lets-users-create-agent-blueprints-by-default/)

<!--- Results --->
%TestResult%
