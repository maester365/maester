This check inventories the `Default-Query-Policy` object and any explicit `lDAPAdminLimits` values. If the object or explicit limits are absent, effective LDAP limits may still be supplied by directory defaults; absence alone is not proof that LDAP queries are unlimited.

#### Remediation action

Review effective LDAP query policy limits and any per-DC overrides before changing settings. Confirm that limits accommodate legitimate applications and are aligned with your organization's availability baseline.

#### Related links

- [Microsoft: LDAP policies](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/view-set-ldap-policy-using-ntdsutil)

<!--- Results --->
%TestResult%
