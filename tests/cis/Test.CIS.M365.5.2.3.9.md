The smart lockout duration is set and is not shorter than the recommended minimum.

When smart lockout triggers, the account is locked for the configured duration. A very short duration lets an attacker resume guessing almost immediately, which cancels the benefit of the threshold.

The test passes only when the duration has been set explicitly in the tenant's password rule settings. Lockout threshold is checked by a separate test.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Password protection**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection).
3. Set **Lockout duration in seconds** to 60 or more.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Password protection](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)
* [Protect user accounts from attacks with Microsoft Entra smart lockout](https://learn.microsoft.com/entra/identity/authentication/howto-password-smart-lockout)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.9](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
