Should have User.Read granted with admin consent for linked applications

Any application linked to an Entra External ID user flow (via
`conditions.applications.includeApplications`) depends on the user flow to
sign users in and read their basic profile. If the application does not have
the Microsoft Graph delegated permission `User.Read` granted, or if that
permission has only been consented to per-user rather than by an
administrator (`consentType = AllPrincipals`), users can hit interactive
consent prompts or sign-in failures, and the sign-in experience will not be
consistent for every user.

This test checks every (user flow, linked application) pair and lists all
applications whose service principal does not have a Microsoft Graph
`User.Read` delegated permission grant with `AllPrincipals` (admin) consent.

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CustomAuthenticationExtensionsMenuBlade/~/UserFlows), open **App registrations**.
2. Select the affected application listed in the results below.
3. Go to **API permissions** and ensure **Microsoft Graph > User.Read** (delegated) is listed.
4. Select **Grant admin consent** for the tenant.

#### Related links

- [Register an application with the Microsoft identity platform](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)

<!--- Results --->
%TestResult%
