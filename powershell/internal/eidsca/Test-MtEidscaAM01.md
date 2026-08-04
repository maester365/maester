Whether the Authenticator App is enabled in the tenant.

enabled

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
.state -eq 'enabled'
```

#### Remediation action

[Microsoft Learn - Enable Authenticator App](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods-manage#authentication-methods-policy)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [microsoftAuthenticatorAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/microsoftauthenticatorauthenticationmethodconfiguration)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)



<!--- Results --->
%TestResult%
