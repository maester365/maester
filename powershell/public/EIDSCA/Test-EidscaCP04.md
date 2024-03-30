Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???

If this option is set to enabled, then users request admin consent to any app that requires access to data they do not have the permission to grant. If this option is set to disabled, then users must contact their admin to request to consent in order to use the apps they need.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value` was **%TestResult%**

The recommended value is **'true'**
