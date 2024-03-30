Default Settings - Password Rule Settings - Enforce custom list

When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.

<!--- Results --->

In your tenant `graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value` was **%TestResult%**

The recommended value is **'True'**
