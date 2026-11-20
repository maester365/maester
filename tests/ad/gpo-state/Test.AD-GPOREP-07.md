Checks GPO permission reports for deny access entries. Any evaluated GPO with a
deny entry is a finding and fails this test. This read-only assessment of
preventive ACL settings does not determine the entry's effective impact or modify
the descriptor.

#### Control Type

**Detective**

#### Why This Test Matters

Deny entries can restrict access even when allow entries also exist. Unintended
restrictions can prevent intended recipients from retrieving or applying security
policy. Some restrictions may be deliberate. Review each entry's
scope and purpose before changing it; this check does not determine whether a deny
entry is excessive or necessary.

#### Security Recommendation

Investigate deny entries against the intended policy scope and delegation. Retain
documented, necessary restrictions; remove an entry only after confirming it is
unintended and assessing its effect on policy recipients.

#### How the Test Works

- Checks `HasDenyAce` in the cached GPO permission reports.
- A known deny entry is a finding. Descriptors that cannot be evaluated remain
  unknown rather than being treated as clean.
- If all reports are unknown, the test is skipped; partial unknowns without
  findings result in **Investigate**. Findings still fail when other reports are
  unknown. Failed report collection is an error.
- Windows is required for security-descriptor parsing. Details are shown for
  findings or unknown reports.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO under **Delegation** >
   **Advanced**.
2. Confirm the purpose and scope of each deny entry. Remove only restrictions
   verified as unintended, and review the effect on policy recipients first.
   Investigate descriptors that could not be evaluated.

#### Related Tests

- [AD-GPOREP-03 — GPOs should include Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-03) (`Test-MtAdGpoNoAuthenticatedUsersCount`) assesses a selected allowed-principal entry that may be affected by deny entries.
- [AD-GPOREP-05 — GPOs should include Enterprise Domain Controllers permissions](https://maester.dev/docs/tests/AD-GPOREP-05) (`Test-MtAdGpoNoEnterpriseDcCount`) assesses a selected allowed-principal entry that may be affected by deny entries.
- [AD-GPOREP-06 — GPOs should include Domain Computers or Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-06) (`Test-MtAdGpoNoDomainComputersCount`) assesses selected allowed-principal entries that may be affected by deny entries.
- [AD-GPOREP-09 — GPOs should not inherit permission entries](https://maester.dev/docs/tests/AD-GPOREP-09) (`Test-MtAdGpoInheritedPermissionsCount`) reports inherited permission entries alongside deny entries.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
