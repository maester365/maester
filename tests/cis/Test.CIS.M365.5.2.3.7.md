The email one-time passcode (Email OTP) authentication method is disabled in the Microsoft Entra authentication methods policy.

Email OTP sends a passcode to an email address, and Microsoft Entra uses it to sign in B2B guest users who cannot authenticate with another method. Whoever controls or intercepts that inbox can sign in as the guest, and the inbox of an external user is outside your control. A phished or compromised mailbox then gives access to the resources the guest can reach.

Disabling the method means unverified guests can no longer redeem invitations with an emailed passcode. They must use a Microsoft account, a Microsoft Entra account, a federated identity provider or a social identity provider, or be configured as a guest in your tenant.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Authentication methods** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods).
3. Select **Email OTP**.
4. Set **Enable** to off.
5. Select **Save**.

To disable the method with PowerShell, connect with `Connect-MgGraph -Scopes 'Policy.ReadWrite.AuthenticationMethod'` and run:

```powershell
$params = @(
    @{ Id = 'Email'; State = 'disabled' }
)
Update-MgPolicyAuthenticationMethodPolicy -AuthenticationMethodConfigurations $params
```

#### Related links

* [Microsoft Entra admin center - Authentication methods policies](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)
* [How to migrate to the Authentication methods policy](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods-manage)
* [Email one-time passcode authentication for B2B guest users](https://learn.microsoft.com/entra/external-id/one-time-passcode)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.3.7](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
