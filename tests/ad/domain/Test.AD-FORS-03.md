Inventories additional forest SPN suffix metadata for investigation. Review the reported values against the intended namespace and service-registration design; the suffix list is not proof that individual SPNs are valid or that a service is reachable.

SPNs identify services for Kerberos authentication. Forest SPN suffix configuration can support service-registration design, but actual SPNs on accounts must be assessed separately.

#### Control Type

**Operational**

#### Security Recommendation

Confirm ownership of each configured suffix before changing forest configuration. Use AD-SPN-01, AD-SPN-06 and AD-SPN-12 to assess actual computer, user and privileged-account SPNs. Do not remove a suffix based only on its count. Document intentional namespaces and investigate unexplained additions.

#### How the Test Works

Counts and displays additional forest SPN suffix metadata. It does not validate Kerberos tickets, individual SPN registrations or service reachability.

#### Related Tests

- **AD-FORS-01 — Alternate UPN suffix inventory for review** — `Test-MtAdUpnSuffixesCount` — Inventories UPN suffixes separately.
- **AD-SPN-01 — Computer SPN service class count should be retrievable** — `Test-MtAdComputerSpnServiceClassCount` — Inventories computer SPN classes, not suffixes.
- **AD-SPN-06 — User SPN total count should be investigated** — `Test-MtAdUserSpnTotalCount` — Inventories user SPNs, not forest suffixes.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
