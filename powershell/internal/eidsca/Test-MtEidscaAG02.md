Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.

Allows to integrate report of fraud attempt by users to identity protection: Users who report an MFA prompt as suspicious are set to High User Risk. Administrators can use risk-based policies to limit access for these users, or enable self-service password reset (SSPR) for users to remediate problems on their own.

#### Test script
```
https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
.reportSuspiciousActivitySettings.state -eq 'enabled'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=policies/authenticationMethodsPolicy&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [Get authenticationMethodsPolicy - Microsoft Graph v1.0 | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/authenticationmethodspolicy-get)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AuthMethodsSettings)

<!--- Results --->
%TestResult%
