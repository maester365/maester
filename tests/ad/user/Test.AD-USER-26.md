Only account SIDs, distinguished names or sAMAccountNames explicitly supplied in `AccountIds` are treated as decoys. Without configured IDs this check is not applicable; unknown IDs error. Attractive words in a name are never proof of a decoy.

#### Control Type

**Operational**

#### Security Recommendation

Document deliberately configured decoy identities and verify their authentication alerts independently. Never infer decoy status from an attractive account name.

#### How the Test Works

The test inventories only the account SIDs, distinguished names or sAMAccountNames explicitly listed in `AccountIds`; unconfigured IDs make it not applicable and unknown IDs error. It does not verify alerting.

#### Related Tests

- **AD-USER-20 — Service-like user names should be reviewed** — `Test-MtAdUserKnownServiceAccountCount` — Inventories naming patterns but does not identify decoys.

#### Remediation action
1. Identify authorized decoy accounts and configure their IDs; review the accounts in [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Confirm alert coverage for attempted authentication separately; this test does not test monitoring.

<!--- Results --->
%TestResult%
