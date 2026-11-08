#### Test-MtAdGpoAllSettingsDisabledDetails

 Returns details of GPOs where all settings are disabled.

#### Why This Test Matters
- Detective control: lists GPOs where all settings are disabled which can be a sign of misconfiguration or excessive restriction.

#### Control Type

**Operational**

#### Security Recommendation
- Review fully disabled GPOs; decide whether to re-enable or remove them.

#### How the Test Works
- Identifies GPOs with GpoStatus AllDisabled and renders a detailed MD table of those GPOs.

#### Related Tests
- **AD-GPOS-04 — Disabled GPO settings count should be investigated** — `Test-MtAdGpoSettingsDisabledCount` — Provides the state-wide disabled-settings count.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
