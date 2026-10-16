Defines if list of AADGUID will be used to allow or block registration.

You should use Block or Allow as value to allow- or blocklisting of AAGuids.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
.keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') -eq 'true'
```

#### Remediation action

[Microsoft Learn - Enable passkeys (FIDO2) for your organization: Restrict specific keys](https://learn.microsoft.com/entra/identity/authentication/how-to-enable-passkey-fido2#passkey-optional-settings)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/fido2authenticationmethodconfiguration)




<!--- Results --->
%TestResult%
