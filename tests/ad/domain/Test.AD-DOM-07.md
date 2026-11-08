Validates every forest domain partition's NetBIOS name for the 15-character limit and disallowed characters. Displays each partition DN, NetBIOS name and syntax outcome. Missing partition metadata is an error.

Legacy applications, scripts and Windows networking components may still use NetBIOS names. Invalid characters or overlong names can cause interoperability problems; a valid name does not guarantee legacy-client compatibility.

#### Control Type

**Preventive**

#### Security Recommendation

Verify invalid names against the directory and plan a supported domain rename or migration with AD administrators; do not directly edit partition metadata. For new names, prefer short alphanumeric choices even when additional characters are permitted, and document exceptions.

#### How the Test Works

Checks NetBIOS names on forest domain partitions for length and prohibited characters, reporting each partition and its result. Missing names or partition metadata are not silently accepted.

#### Related Tests

- **AD-DOM-05 — Forest domain DNS names have valid syntax** — `Test-MtAdDomainNameStandardCompliance` — Reviews DNS names alongside NetBIOS names.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
