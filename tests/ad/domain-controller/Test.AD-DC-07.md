Checks inventoried DCs in the connected domain against the configurable minimum Windows Server release (default 2022). Reports each assessed DC's directory OS name, OS version and classified release alongside counts and the baseline decision. DCs belonging to other domains are excluded and counted separately; assess those domains with their own connections. Missing or conflicting OS metadata for an in-scope DC remains an error. Directory metadata does not verify patch installation or contractual support.

Older DC operating systems can constrain directory capabilities and upgrade planning. Release classification helps prioritize review but cannot establish security-update state or Microsoft's current lifecycle status.

#### Control Type

**Operational**

#### Security Recommendation

Plan replacement or upgrade of DCs below the chosen minimum with AD administrators; verify replication, roles and application dependencies before decommissioning an older DC. Independently assess installed updates and vendor support. Document the approved baseline and maintain a separate patch and support inventory.

#### How the Test Works

Scopes the shared DC inventory to the connected domain's distinguished name (with exact DNS-root fallback), then classifies only those DCs using directory OS name and version. Other-domain lookup failures do not fail this scoped assessment. Unknown or contradictory in-scope OS evidence remains an error, not evidence of compliance; the collector's forest inventory is not modified.

#### Related Tests

- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories connected-domain controllers.
- **AD-DOM-01 — Domain functional level meets the highest supported common level** — `Test-MtAdDomainFunctionalLevel` — Reviews domain functional level separately.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [Microsoft: Windows Server release information](https://learn.microsoft.com/windows-server/get-started/windows-server-release-info)
* [ANSSI: DC or RODC with an obsolete operating system](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_dc_obsolete)

<!--- Results --->
%TestResult%
