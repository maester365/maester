Default Settings - Consent Policy Settings - Group owner consent for apps accessing data

Group and team owners can authorize applications, such as applications published by third-party vendors, to access your organization's data associated with a group. For example, a team owner in Microsoft Teams can allow an app to read all Teams messages in the team, or list the basic profile of a group's members.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value` was **%TestResult%**

The recommended value is **'False'**
