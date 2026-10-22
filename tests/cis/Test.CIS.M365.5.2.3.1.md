Microsoft Authenticator is enabled for all users and its push notifications show the application name and the geographic location of the sign-in request.

In an MFA fatigue attack, an attacker who has a user's password triggers repeated push prompts until the user approves one. Showing which application is signing in and from where gives the user the information needed to recognise and deny a request they did not start.

The change affects the Authenticator prompt only. Users see extra context, and number matching stays in place.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods).
3. Select **Microsoft Authenticator**, set **Enable** to on and target **All users**.
4. On the **Configure** tab, set **Show application name in push and passwordless notifications** to **Enabled** and target **All users**.
5. Set **Show geographic location in push and passwordless notifications** to **Enabled** and target **All users**.
6. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Authentication methods policies](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)
* [Use additional context in Microsoft Authenticator notifications](https://learn.microsoft.com/entra/identity/authentication/how-to-mfa-additional-context)
* [How number matching works in multifactor authentication push notifications](https://learn.microsoft.com/entra/identity/authentication/how-to-mfa-number-match)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
