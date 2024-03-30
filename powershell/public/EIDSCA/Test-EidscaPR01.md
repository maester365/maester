Default Settings - Password Rule Settings - Password Protection - Mode

If set to Enforce, users will be prevented from setting banned passwords and the attempt will be logged. If set to Audit, the attempt will only be logged.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value` was **%TestResult%**

The recommended value is **'Enforce'**
