Inventories standalone managed service accounts (sMSA), group managed service accounts (gMSA), and delegated managed service accounts (dMSA).

dMSAs were first implemented in Windows Server 2025 and are subclasses of computer objects. The inventory reports `DelegatedMsaState` when available, but does not infer dMSA support from functional level or establish effective service-account password rotation. The count is for review, not a security pass/fail threshold.

#### Remediation action

1. Review the accounts and their service owners; evaluate whether conventional service identities can migrate to managed accounts.
2. Validate hosting, authorization, and lifecycle arrangements before migrating services.

#### Related links

* [Microsoft Learn: Managed service accounts overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-service-accounts)

<!--- Results --->
%TestResult%
