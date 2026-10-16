Whether the Temporary Access Pass is enabled in the tenant.

Use Temporary Access Pass for secure onboarding users (initial password replacement) and enforce MFA for registering security information in Conditional Access Policy.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
.state -eq 'enabled'
```

#### Remediation action

[Microsoft Learn - Enable Temporary Access Pass](https://learn.microsoft.com/entra/identity/authentication/howto-authentication-temporary-access-pass#enable-the-temporary-access-pass-policy)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [temporaryAccessPassAuthenticationMethodConfiguration resource type - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration)




<!--- Results --->
%TestResult%
