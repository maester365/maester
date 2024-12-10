Defines whether user consent will be blocked when a risky request is detected

[Configure risk-based step-up consent - Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/configure-risk-based-step-up-consent)

#### Test script
```
https://graph.microsoft.com/beta/settings
.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)


<!--- Results --->
%TestResult%
