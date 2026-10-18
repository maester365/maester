Microsoft Authenticator functionality on companion applications, such as Outlook, is disabled.

When this feature is on, a user can approve a sign-in request from within a companion app on the same phone that is used to sign in. Approving on the device that started the request weakens the separation between the first factor and the second factor, and a compromised app or device can then complete both.

Disabling it means approvals are given only in the Microsoft Authenticator app itself.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods).
3. Select **Microsoft Authenticator** and open the **Configure** tab.
4. Set **Microsoft Authenticator on companion applications** to **Disabled**.
5. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Authentication methods policies](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)
* [Enable Microsoft Authenticator on companion applications](https://learn.microsoft.com/entra/identity/authentication/how-to-mfa-authenticator-lite)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
