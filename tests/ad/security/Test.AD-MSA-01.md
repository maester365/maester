Inventories standalone managed service accounts (sMSA), group managed service accounts (gMSA), and delegated managed service accounts (dMSA).

Managed service accounts can reduce manual password management and credential reuse. gMSAs can serve multiple authorized hosts; standalone MSAs are tied to a single host. Account presence alone cannot establish that an application has migrated or that managed credentials are in use.

dMSAs were first implemented in Windows Server 2025 and are subclasses of computer objects. The inventory reports `DelegatedMsaState` when available, but does not infer dMSA support from functional level or establish effective service-account password rotation. The count is for review, not a security pass/fail threshold.

Managed accounts can reduce manual password changes and shared-credential reuse when applications actually use them. Standalone MSAs serve one host; gMSAs serve multiple authorized hosts. Their configured rotation interval and service use must be verified separately rather than inferred from an inventory count.

#### Control Type

**Operational**

#### Security Recommendation

Where supported, consider gMSAs for new services and prioritize migration of sensitive conventional service identities. Document authorized hosts, rights and lifecycle ownership; verify compatibility before changing an account.

Plan migration per service, confirm application support and grant only the required rights to authorized hosts. gMSAs depend on a usable KDS root key; use the visibility-aware key assessment before deciding whether a key must be provisioned. Do not create another key merely because a restricted reader saw none.

#### Remediation action

1. Review the accounts and their service owners; evaluate whether conventional service identities can migrate to managed accounts.
2. Validate hosting, authorization, and lifecycle arrangements before migrating services.

#### How the Test Works

The check enumerates collected sMSA, gMSA and dMSA objects and reports account counts and available states for review. It does not read managed passwords or verify that services use the identities.

#### Related Tests

- **AD-DCOMP-03 — Non-DC computer and managed account constrained delegation should be investigated** — `Test-MtAdComputerNonDcConstrainedDelegationCount` — Reviews constrained delegation for managed accounts.

#### Related links

* [Microsoft Learn: Managed service accounts overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-service-accounts)

#### References

- [Microsoft: Group managed service accounts](https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)
- [Microsoft: Getting started with group managed service accounts](https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/getting-started-with-group-managed-service-accounts)

<!--- Results --->
%TestResult%
