Determines whether the pass is limited to a one-time use.

Avoid to allow reusable passes and restrict usage to one-time use (if applicable)

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
.isUsableOnce -eq 'true'
```

#### Remediation action

[Microsoft Learn - Require one-time use (Step 5)](https://learn.microsoft.com/entra/identity/authentication/howto-authentication-temporary-access-pass#enable-the-temporary-access-pass-policy)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration)




<!--- Results --->
%TestResult%
