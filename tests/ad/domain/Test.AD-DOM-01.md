Checks that the connected domain's functional level equals the highest common level supported by its DCs. A lower level prevents use of newer directory capabilities; a level above collected DC support requires investigation of incompatible or stale inventory.

Higher functional levels enable capabilities such as privileged access management and authentication policies. Raising the level requires checking application compatibility as well as the DC operating systems; the configured level alone does not establish which features have been deployed.

#### Control Type

**Preventive**

#### Security Recommendation

1. Verify the connected domain's DC inventory and operating-system releases; do not mix in other forest domains.
2. Plan upgrades of legacy DCs and review application compatibility and recovery requirements.
3. Raise the domain functional level only after every DC supports it. Windows Server 2025 uses level 10; Server 2016/2019/2022 use level 7. Missing or conflicting metadata must be resolved first.

Schedule and document the change with directory administrators after testing dependent applications.

#### How the Test Works

Compares the connected domain's functional level with the highest common supported level of its in-scope DCs. Missing or inconsistent DC OS evidence is not treated as a supported release; this is no longer an informational readout of the current level alone.

#### Related Tests

- **AD-FOR-01 — Forest functional level meets connected-domain DC support** — `Test-MtAdForestFunctionalLevel` — Reviews the forest level against connected-domain DC support.
- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories domain controllers.

#### Related links

* [Microsoft: Active Directory functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-functional-levels)
* [Microsoft: Raise domain and forest functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/raise-domain-forest-functional-levels)
* [ANSSI: Insufficient forest and domain functional levels](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_functional_level)

<!--- Results --->
%TestResult%
