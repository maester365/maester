Checks whether each evaluated GPO has permission entries. A readable GPO with no entries is a finding and fails the test. Unreadable permission data is reported as unknown, not as an empty list: if all permissions are unreadable, the test is skipped; if collection is partial and no finding is present, the result is **Investigate**. Failed permission-report collection is an error.

The result summarizes evaluated, empty, and unknown permission reports. Details are shown only for findings or unknown reports.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Delegation** > **Advanced** security settings.
2. Restore intended permissions and confirm that authorized administrators and policy recipients retain required access. Investigate descriptors that could not be read before treating the inventory as complete.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
