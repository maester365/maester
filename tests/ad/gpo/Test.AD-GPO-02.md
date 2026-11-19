Checks that each GPO's last modification is no more than `MaximumAgeYears` old, defaulting to five calendar years. A modification exactly at the cutoff passes; only an older modification fails. Creation and modification dates are shown together, so an old creation date alone does not fail a recently maintained policy. An empty inventory, missing modification date, or unavailable inventory is an error.

Age is a hygiene indicator, not proof of insecure settings. LDAP `whenChanged` is specific to the queried domain controller and can reflect metadata or permission changes, not just policy settings. The result reports total and stale GPO counts, the cutoff, and each policy's assessment.

Configure `MaximumAgeYears` under `TestSettings` > `Parameters` for `AD-GPO-02` in `maester-config.json`, or pass it through `Invoke-MtTest -Parameter`.

#### Remediation action

1. In **Group Policy Management**, review stale policies with their owners and compare their settings with current security baselines.
2. Update obsolete settings and verify intended scope, or archive and remove policies that are no longer needed. Do not edit a policy merely to refresh its timestamp.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
