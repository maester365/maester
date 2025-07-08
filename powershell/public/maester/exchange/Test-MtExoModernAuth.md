Modern authentication for Exchange Online MUST be enabled

Rationale: Modern authentication enables enhanced security features like multifactor authentication (MFA), certificate-based authentication (CBA), and third-party SAML identity providers. Without modern authentication, users are more vulnerable to password-based attacks.

#### Remediation action:

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Enable modern authentication:
```powershell
Set-OrganizationConfig -OAuth2ClientProfileEnabled $true
```

3. Verify the setting:
```powershell
(Get-OrganizationConfig).OAuth2ClientProfileEnabled
```
The result should be `True`.

#### Related links

* [Enable or disable modern authentication in Exchange Online](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/enable-or-disable-modern-authentication-in-exchange-online)
* [Modern authentication overview](https://learn.microsoft.com/en-us/microsoft-365/enterprise/modern-auth-for-office-2013-and-2016)
* [Microsoft Secure Score - Enable modern authentication](https://security.microsoft.com/securescore)

<!--- Results --->
%TestResult%