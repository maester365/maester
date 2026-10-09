#### Test-MtAdGpoEnforcementCount

 Counts the number of GPOs that have enforced GPO links.

#### Why This Test Matters
- Detective control: counts GPOs with enforced links which indicates explicit policy delivery is configured.

#### Control Type

**Operational**

#### Security Recommendation
- Ensure enforcement aligns with security policy; adjust as needed for least privilege and correct policy propagation.

#### How the Test Works
- Fetches GPO state, filters for HasEnforcement, and reports total GPOs, number with enforcement, and the ratio.

#### Related Tests
- `Test-MtAdGpoEnforcementCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
