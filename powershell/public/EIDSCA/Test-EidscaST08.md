Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner

Indicating whether or not a guest user can be an owner of groups

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value` was **%TestResult%**

The recommended value is **'false'**
