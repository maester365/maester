Default Settings - Consent Policy Settings - Block user consent for risky apps

Defines whether user consent will be blocked when a risky request is detected

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value` was **%TestResult%**

The recommended value is **'true'**
