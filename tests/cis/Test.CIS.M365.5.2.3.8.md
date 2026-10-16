The smart lockout threshold is set and does not exceed the recommended maximum of failed sign-in attempts.

Smart lockout slows password guessing and spraying by locking an account out after a number of failed sign-ins. A high threshold gives an attacker more guesses per lockout period.

The test passes only when the threshold has been set explicitly in the tenant's password rule settings. Lockout duration is checked by a separate test.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Password protection**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection).
3. Set **Lockout threshold** to 10 or less.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Password protection](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)
* [Protect user accounts from attacks with Microsoft Entra smart lockout](https://learn.microsoft.com/entra/identity/authentication/howto-password-smart-lockout)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
