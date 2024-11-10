Defines if list of AADGUID will be used to allow or block registration.

You should use Block or Allow as value to allow- or blocklisting of AAGuids.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
.keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') -eq 'true'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [fido2AuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/fido2authenticationmethodconfiguration)


<!--- Results --->
%TestResult%
