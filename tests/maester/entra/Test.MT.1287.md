User consent grants to third-party apps should not remain after user consent is restricted.

When users consent to an app for themselves, Microsoft Entra ID records a delegated permission grant, and the app can access data on their behalf. Restricting user consent only affects future consents: the grants given before the change remain, and the apps keep their access until an administrator revokes the grants. This includes an app that users consented to through a consent phishing campaign.

This check reads the consent policies assigned to the default user role, then the delegated permission grants that users gave for themselves. It lists the third-party apps that hold such grants, with their verified publisher, the number of users and the permissions granted. Microsoft first-party apps and apps registered in your tenant are not listed. Neither are apps whose sign-in is disabled: tokens aren't issued for them.

- **User consent is turned off**: every remaining grant predates the change, and the test fails.
- **User consent is limited**, for example to apps from verified publishers for selected permissions: the current policy may allow some of the grants, so the result asks for a review.
- **Users can consent to any app**: the grants are expected, and the test is skipped. Restrict user consent first: EIDSCA.AP08 checks this setting.

An administrator can also grant consent on behalf of a single user through Microsoft Graph. Such a grant looks the same as user consent: check with the app owner before you revoke it.

### Remediation action:

1. Sign in to the [Microsoft Entra admin center][entra-admin-center] as at least a Cloud Application Administrator.
2. Open each reported app from the result table. The **User consent** tab of its **Permissions** page lists the permissions that users granted.
3. Decide with the app owner or the users whether the app is still needed. To let users request an app they need, [enable the admin consent workflow][admin-consent-workflow].
4. The admin center can't revoke the permissions on the **User consent** tab. Revoke them with Microsoft Graph PowerShell, using the **Object ID** shown on the app's **Overview** page:

   ```powershell
   Connect-MgGraph -Scopes 'DelegatedPermissionGrant.ReadWrite.All'
   Get-MgOauth2PermissionGrant -All -Filter "clientId eq '<object id>'" |
       Where-Object ConsentType -eq 'Principal' |
       ForEach-Object { Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId $_.Id }
   ```

5. To block an app at once while you review it, set **Enabled for users to sign in?** to **No** on its **Properties** page: tokens are no longer issued for it.

### Related links

* [Configure how users consent to applications][user-consent]
* [Review permissions granted to enterprise applications][review-permissions]
* [Configure the admin consent workflow][admin-consent-workflow]
* [Properties of an enterprise application: Enabled for users to sign in?][app-properties]

[entra-admin-center]: https://entra.microsoft.com
[user-consent]: https://learn.microsoft.com/entra/identity/enterprise-apps/configure-user-consent
[review-permissions]: https://learn.microsoft.com/entra/identity/enterprise-apps/manage-application-permissions
[admin-consent-workflow]: https://learn.microsoft.com/entra/identity/enterprise-apps/configure-admin-consent-workflow
[app-properties]: https://learn.microsoft.com/entra/identity/enterprise-apps/application-properties#enabled-for-users-to-sign-in

<!--- Results --->
%TestResult%
