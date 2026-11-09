#### Control Type

**Detective**

#### Test-MtAdGpoNoEnterpriseDcCount

 Counts GPO reports that do not include Enterprise Domain Controllers.

#### Why This Test Matters
- Detective control: flags GPO reports missing Enterprise Domain Controllers which could impact domain-wide policy targeting.

#### Security Recommendation
- Verify whether Enterprise DCs should be included; adjust policy accordingly.

#### How the Test Works
- Retrieves GPO state, enumerates GPO reports, and counts those without an access-allowed entry for Enterprise Domain Controllers (HasEnterpriseDomainControllers is false).
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.


#### Related Tests

- **AD-GPOREP-06 — GPOs without domain computers count should be retrievable** — `Test-MtAdGpoNoDomainComputersCount` — Reviews another computer-recipient permission cohort separately.
- **AD-GPOREP-03 — GPOs should permit Authenticated Users where required** — `Test-MtAdGpoNoAuthenticatedUsersCount` — Reviews alternative GPO security filtering; missing a named group alone does not establish a policy gap.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
