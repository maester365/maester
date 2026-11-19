Counts GPOs whose readable permissions do not include **Authenticated Users**. This is a review signal, not a universal ACL requirement: security filtering may intentionally use other groups, so verify intended scope before changing permissions. GPOs whose permissions cannot be read are reported as unknown, not missing.

If no GPO permissions can be evaluated, the test is skipped. If some permissions are unknown and no missing-Authenticated-Users finding is present, the result is **Investigate**; findings among evaluated GPOs still fail the test.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Scope** > **Security Filtering** and **Delegation** > **Advanced** settings.
2. Confirm the intended recipients and read/apply permissions. Do not grant **Apply Group Policy** to everyone solely to clear this finding; remediate only when the current ACL does not match the intended policy scope. Investigate GPOs whose permissions could not be read.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
