Every member user has registered at least one authentication method that can satisfy multifactor authentication.

A Conditional Access policy that requires MFA only helps if users can complete it. A user who has not registered a usable method is either locked out when the policy is enforced or is excluded from it, and in both cases the account is protected by a password alone.

The test reads the registration report, which can lag behind recent changes by a short time. Accounts that are not used for interactive sign-in should be reviewed and, if no longer needed, disabled or removed.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**User registration details**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/UserRegistrationDetails).
3. Filter on **Is MFA capable** = **No** and **User type** = **Member**.
4. Ask each listed user to register a method at [https://aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo), or enable a registration campaign or a Conditional Access policy for the security information registration user action.
5. Disable or delete accounts that are no longer in use.

#### Related links

* [Microsoft Entra admin center - User registration details](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/UserRegistrationDetails)
* [Authentication methods activity](https://learn.microsoft.com/entra/identity/authentication/howto-authentication-methods-activity)
* [Nudge users to set up Microsoft Authenticator](https://learn.microsoft.com/entra/identity/authentication/how-to-mfa-registration-campaign)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
