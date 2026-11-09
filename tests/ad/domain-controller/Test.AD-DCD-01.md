Reports both LDAP and LDAPS port metadata for each forest DC, with known, unknown and nonstandard counts against 389 and 636. Current collector values are unmeasured, not proof of default ports or live listeners. This inventory does not test TLS certificates or network reachability.

LDAP clients commonly expect port 389 and LDAPS clients port 636. Documented deviations can affect firewall and client configuration; an unknown port is not a detected alternate port or evidence of evasion.

#### Control Type

**Detective**

#### Security Recommendation

Review advertised configuration if it is available; use separate connectivity and TLS tests from the relevant client networks before making any network or certificate changes. Document intentional deviations, check firewall rules and investigate unauthorized changes using independently collected evidence.

#### How the Test Works

Reports known, unknown and nonstandard LDAP/LDAPS port metadata against 389/636 for inventoried DCs. Unmeasured collector values remain unknown; this test does not probe listeners.

#### Related Tests

- **AD-DC-01 — Site DNs containing DC objects for review** — `Test-MtAdDcSiteCoverageCount` — Inventories DC site DNs.
- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories connected-domain controllers.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
