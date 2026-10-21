System-preferred multifactor authentication is enabled and applies to all users.

With the feature on, Microsoft Entra ID prompts for the most secure method the user has registered and that is allowed, rather than the method the user picked last or a weaker default. Users who registered both an authenticator app and SMS are asked to use the app, which resists interception and phishing better.

Users can still choose another method from the prompt. The setting only changes which method is offered first.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Settings**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods).
3. Set **System-preferred multifactor authentication** to **Enabled**.
4. Set the target to **All users**.
5. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Authentication methods policies](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)
* [System-preferred multifactor authentication](https://learn.microsoft.com/entra/identity/authentication/concept-system-preferred-multifactor-authentication)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
