Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

Manages if guest accounts can access resources through Microsoft 365 Group membership and could break collaboration if you disable it.

#### Test script
```
https://graph.microsoft.com/beta/settings
.values -eq 'True'
```

#### Remediation action

[Microsoft Learn - Microsoft Entra cmdlets for configuring group settings](https://learn.microsoft.com/entra/identity/users/groups-settings-cmdlets#update-settings-at-the-directory-level)

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/directorysetting)




<!--- Results --->
%TestResult%
