Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds

The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value` was **%TestResult%**

The recommended value is **'60'**
