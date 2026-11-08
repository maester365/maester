DES-only user Kerberos keys weaken encryption and expose authentication material to offline attack.

#### Remediation action
1. Identify legacy applications requiring DES with their owners.
2. Migrate to modern Kerberos encryption and clear the DES-only setting in [AD account settings](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers).

<!--- Results --->
%TestResult%
