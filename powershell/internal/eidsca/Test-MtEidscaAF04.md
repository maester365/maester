Manages if registration of FIDO2 keys should be restricted.

Restrict usage of FIDO2 from unauthorized vendors or platforms

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
.keyRestrictions.isEnforced -eq 'true'
```

#### Remediation action

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Enforce key restrictions](https://learn.microsoft.com/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/fido2authenticationmethodconfiguration)




<!--- Results --->
%TestResult%
