Checks for inherited permission entries in GPO security descriptors. Any evaluated GPO with an inherited entry is a finding and fails the test; this is a permission-entry check, not a test of whether permissions could be retrieved. Unreadable descriptors are reported as unknown. If all are unreadable, the test is skipped; partial unknowns without findings require investigation. Findings still fail when other descriptors are unknown. Failed permission-report collection is an error.

The summary and metrics table report GPOs with inherited entries and unreadable descriptors. With no findings or unknown reports, the summary says no inherited entries were found; the details table appears only for findings or unknown reports.

#### Remediation action

Review each listed inherited entry and its source container. Confirm whether inherited access matches intended GPO delegation before changing inheritance or permissions; do not treat inheritance itself as a retrieval failure. Investigate unreadable descriptors.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
