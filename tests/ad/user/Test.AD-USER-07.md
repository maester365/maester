Disabling Kerberos pre-authentication permits AS-REP roasting: an attacker can request crackable material without the password.

#### Remediation action
1. Confirm dependencies and enable Kerberos pre-authentication on affected [AD user accounts](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Rotate exposed credentials according to incident-response policy.

<!--- Results --->
%TestResult%
