Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold

How many failed sign-ins are allowed on an account before its first lockout. If the first sign-in after a lockout also fails, the account locks out again.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutThreshold' | select-object -expand value` was **%TestResult%**

The recommended value is **'10'**
