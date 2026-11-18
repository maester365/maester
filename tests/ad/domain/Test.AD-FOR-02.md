Reports the number and names of domains in the forest. A domain count is a topology fact for review, not proof that trusts or cross-forest access are configured securely.

Forest domain inventory helps define administrative and recovery scope across domain policies. Domains are not independent security boundaries against a compromised forest administrator; trust and access require their own assessments.

#### Control Type

**Operational**

#### Security Recommendation

Review the inventory with Active Directory administrators. Confirm missing metadata and assess actual requirements before changing configuration. Document each domain's purpose, assess whether the complexity is still justified, and review policies and recovery plans across domains.

#### How the Test Works

Retrieves the forest domain inventory and reports domain names and their count. This is not a trust validation or access audit.

#### Related Tests

- **AD-FOR-01 — Forest functional level meets connected-domain DC support** — `Test-MtAdForestFunctionalLevel` — Reviews the forest level against connected-domain DC support.
- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories controllers for the connected domain.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
