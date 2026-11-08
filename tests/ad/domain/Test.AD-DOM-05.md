Validates each forest domain partition's DNS root using IDNA-compatible DNS label syntax and displays every partition DN, DNS root and result. Missing partition metadata is an error; a syntactically invalid name fails. This does not verify DNS resolution.

Nonstandard domain labels can disrupt application or certificate interoperability. A DNS syntax check does not establish that records resolve or that the namespace is reachable.

#### Control Type

**Preventive**

#### Security Recommendation

Verify invalid DNS roots against the directory and plan a supported namespace or domain migration with AD administrators; do not manually rename partition metadata. Prefer conventional labels without spaces or underscores, within DNS label length limits, when planning new domains.

#### How the Test Works

Examines each forest domain partition's DNS root and checks IDNA-compatible label syntax; missing partition metadata produces an error rather than a passing result.

#### Related Tests

- **AD-DOM-07 — Forest domain NetBIOS names have valid syntax** — `Test-MtAdNetbiosNameStandardCompliance` — Reviews NetBIOS names alongside DNS names.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
