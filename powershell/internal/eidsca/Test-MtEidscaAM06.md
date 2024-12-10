Determines whether the user's Authenticator app will show them the client app they are signing into.



#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
.featureSettings.displayAppInformationRequiredState.state -eq 'enabled'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)


<!--- Results --->
%TestResult%
