Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory

If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value` was **%TestResult%**

The recommended value is **'True'**
