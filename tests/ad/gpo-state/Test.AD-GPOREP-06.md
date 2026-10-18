#### Control Type

**Detective**

#### Test-MtAdGpoNoDomainComputersCount

 Counts GPO reports that do not include Domain Computers.

#### Why This Test Matters
- Detective control: identifies GPO reports missing Domain Computers which could impact scope or applicability.

#### Security Recommendation
- Verify whether Domain Computers should be included and adjust GpoReports as needed to reflect accurate targeting.

#### How the Test Works
- Reads GPO state, counts the GPO reports without an access-allowed entry for Domain Computers (HasDomainComputers is false), and reports counts and samples.
- The default GPO permissions have no Domain Computers entry, so the test only fails for GPOs that have no entry for Authenticated Users either: computer accounts may be unable to read those GPOs (MS16-072).
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.

#### Related Tests
- `Test-MtAdGpoNoDomainComputersCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
