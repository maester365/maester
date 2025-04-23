If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

[Azure identity &amp; access security best practices - Microsoft Learn](https://learn.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices#enable-password-management)

#### Test script
```
https://graph.microsoft.com/beta/settings
.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value -eq 'True'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)
- [View in Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)

<!--- Results --->
%TestResult%
