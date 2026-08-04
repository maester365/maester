Whether the FIDO2 security keys is enabled in the tenant.

enabled

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
.state -eq 'enabled'
```

#### Remediation action

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Enable FIDO2 security key](https://learn.microsoft.com/entra/identity/authentication/how-to-enable-passkey-fido2#enable-passkey-authentication-method)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/fido2authenticationmethodconfiguration)




<!--- Results --->
%TestResult%
