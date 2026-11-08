Inventories `msDS-AllowedDNSSuffixes`, the domain's configured FQDN suffix list used to identify member computers. It does not authorize computer joins or prove that computers using arbitrary suffixes can join the domain.

#### Remediation action

Review allowed DNS suffix identifiers; this setting does not control authorization to join computers to the domain.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)
* [allowedDNSSuffixes attribute](https://learn.microsoft.com/openspecs/windows_protocols/ms-ada2/956314f4-df79-44ac-bf45-669dbdab07a7)

<!--- Results --->
%TestResult%
