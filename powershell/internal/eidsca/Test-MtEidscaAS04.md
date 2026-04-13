Determines if users can use this authentication method to sign in to Microsoft Entra ID. true if users can use this method for primary authentication, otherwise false.

Avoid to use SMS as primary sign in factor (instead of a password) and consider to implement a MFA or passwordless option also for your special user groups, such as front-line workers.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')
.includeTargets.isUsableForSignIn -eq 'false'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [phoneAuthenticationMethod resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/phoneauthenticationmethod)


<!--- Results --->
%TestResult%
