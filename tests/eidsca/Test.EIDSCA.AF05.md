You can work with your Security key provider to determine the AAGuids of their devices for allowing or blocking usage.



#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
.keyRestrictions.aaGuids -notcontains $null -eq 'true'
```

#### Remediation action

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Restricted AAGUIDS](https://learn.microsoft.com/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/fido2authenticationmethodconfiguration)




<!--- Results --->
%TestResult%
