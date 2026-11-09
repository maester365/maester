Inventories site links under the Active Directory IP and SMTP inter-site transport containers.

Reports each link's transport, cost, replication interval, connected sites and distinguished name. Transport is determined from the parent container, not by whether cost or interval is populated. A cost of zero remains a reported value; no transport or security baseline is asserted.

#### Control Type

**Operational**

#### Security Recommendation

Compare site links and transports to the approved replication topology before changing routes. SMTP presence or a link count alone is not a security verdict.

#### How the Test Works

The test inventories site links under IP and SMTP transport containers, reporting connected sites, cost and interval; transport is read from the parent container, not inferred from cost or interval.

#### Related Tests

- **AD-SITE-01 — Site inventory for review** — `Test-MtAdSiteTotalCount` — Inventories sites referenced by the replication topology.
- **AD-SITE-04 — Site and subnet association health** — `Test-MtAdSiteWithoutSubnetCount` — Checks site/subnet associations separately from replication transport configuration.

#### Remediation action

Compare site links and transports with the approved site topology. Investigate unexpected links with directory replication administrators before modifying production replication routes.

#### Related links

* [Active Directory replication concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts)

<!--- Results --->
%TestResult%
