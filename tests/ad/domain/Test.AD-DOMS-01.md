Inventories `msDS-AllowedDNSSuffixes`, the domain's configured FQDN suffix list used to identify member computers. It does not authorize computer joins or prove that computers using arbitrary suffixes can join the domain.

Consistent computer DNS suffixes can help directory naming and inventory. This list does not replace computer-account creation permissions or a domain-join authorization review.

#### Control Type

**Operational**

#### Security Recommendation

Review allowed DNS suffix identifiers against the organization's namespace, document intentional deviations and update the list as naming plans change; this setting does not control authorization to join computers to the domain.

#### How the Test Works

Reports the domain's configured `msDS-AllowedDNSSuffixes` values and count. It does not test domain joins, effective permissions or computer DNS registrations.

#### Related Tests

- **AD-DOM-05 — Forest domain DNS names have valid syntax** — `Test-MtAdDomainNameStandardCompliance` — Reviews DNS name syntax, not suffix allowance.
- **AD-DOM-07 — Forest domain NetBIOS names have valid syntax** — `Test-MtAdNetbiosNameStandardCompliance` — Reviews NetBIOS name syntax separately.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [allowedDNSSuffixes attribute](https://learn.microsoft.com/openspecs/windows_protocols/ms-ada2/956314f4-df79-44ac-bf45-669dbdab07a7)

<!--- Results --->
%TestResult%
