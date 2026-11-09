Shows the count and individual values of configured alternate forest UPN suffixes. This list does not enumerate user UPNs or show whether any suffix is in use; domain DNS suffixes are independently usable.

Alternate UPN suffixes can support consistent sign-in names during reorganizations or mergers. Their presence is configuration metadata, not evidence of a user's effective sign-in name or a vulnerability.

#### Control Type

**Operational**

#### Security Recommendation

Review alternate suffixes with identity administrators and verify actual user UPN assignments before adding or removing any configured suffix. Document ownership and business purpose, and confirm whether deprecated suffixes are still needed before cleanup.

#### How the Test Works

Reports the count and values of configured alternate forest UPN suffixes; it does not include every domain DNS suffix or examine individual user objects.

#### Related Tests

- **AD-FORS-03 — SPN suffix inventory for review** — `Test-MtAdSpnSuffixesCount` — Inventories forest SPN suffixes separately.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
