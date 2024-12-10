Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

Manages if guest accounts can access resources through Microsoft 365 Group membership and could break collaboration if you disable it.

#### Test script
```
https://graph.microsoft.com/beta/settings
.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value -eq 'True'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)


<!--- Results --->
%TestResult%
