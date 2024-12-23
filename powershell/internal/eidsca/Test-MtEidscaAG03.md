Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.

Apply this feature to all users.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [Get authenticationMethodsPolicy - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AuthMethodsSettings)

<!--- Results --->
%TestResult%
