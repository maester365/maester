Checks that GPOs have been modified within `MaximumAgeYears`, defaulting to five calendar years. The result includes creation and modification dates together. A modification exactly at the cutoff passes; only an older modification fails. An old creation date alone does not fail a recently maintained policy.

Age is a hygiene indicator, not proof of insecure settings. LDAP `whenChanged` is specific to the queried domain controller and can reflect metadata or permission changes, not just policy settings. Missing modification dates or an empty inventory produce an error.

Configure `MaximumAgeYears` under `TestSettings` > `Parameters` for `AD-GPO-02` in `maester-config.json`, or pass it through `Invoke-MtTest -Parameter`.

#### Remediation action

1. In **Group Policy Management**, review listed stale policies with their owners against current security baselines.
2. Update obsolete settings and verify intended scope, or archive and remove policies no longer needed. Do not edit a policy merely to refresh its timestamp.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
