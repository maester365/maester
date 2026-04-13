Reviewing the enabled status of a privileged account when the linked user identity has been disabled is critical to prevent orphaned high‑risk access. If a normal work account is deactivated (for example, because the user left the organization) but the related privileged account remains enabled, an attacker or former employee could still use that privileged identity to access sensitive systems, change security settings, or exfiltrate data unnoticed. Regularly checking and aligning the status of privileged accounts with their primary identities helps enforce least privilege, reduces the attack surface, and ensures that privileges are revoked promptly when a user’s employment or role ends.

### How to fix
Review the results from this check and verify whether it is legitimate for the privileged user account to remain enabled when the associated primary work account has been disabled.

<!--- Results --->
%TestResult%