Linking a privileged user account to the primary work account in Microsoft Defender XDR makes it easier to detect, prioritize, and contain attacks that target highly sensitive identities. It also improves incident response because all relevant activity and risk signals are correlated to the real person behind both identities, reducing blind spots and investigation time.

This use case is explicitly described in the Defender XDR documentation:
A user might have two accounts, one for everyday work and another with elevated permissions for administrative tasks.
Example

john.smith@company.com (regular account)
john.smith.admin@company.com (privileged account)

### How to fix
Review the accounts in the Identity inventory of Microsoft Defender portal and add a [manual link](https://learn.microsoft.com/en-us/defender-for-identity/link-unlink-account-to-identity) from the identity page of the (primary) user account to the privileged account.

<!--- Results --->
%TestResult%
