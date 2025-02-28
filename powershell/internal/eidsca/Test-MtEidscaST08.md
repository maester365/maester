Indicating whether or not a guest user can be an owner of groups, manage

CISA SCuBA 2.18: Guest users SHOULD have limited access to Entra ID (Azure AD) directory objects

#### Test script
```
https://graph.microsoft.com/beta/settings
.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'
```

#### Related links

- [Open in Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer?request=settings&method=GET&version=beta&GraphUrl=https://graph.microsoft.com)
- [directorySetting resource type - Microsoft Graph beta | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/directorysetting)


<!--- Results --->
%TestResult%
