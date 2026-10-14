Allows users to register a FIDO key through the MySecurityInfo portal, even if enabled by Authentication Methods policy.



#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
.isSelfServiceRegistrationAllowed -eq 'true'
```

#### Remediation action

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Allow self-service set up](https://learn.microsoft.com/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/fido2authenticationmethodconfiguration)




<!--- Results --->
%TestResult%
