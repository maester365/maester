Validates each forest domain partition's DNS root using IDNA-compatible DNS label syntax and displays every partition DN, DNS root and result. Missing partition metadata is an error; a syntactically invalid name fails. This does not verify DNS resolution.

#### Remediation action

Verify invalid DNS roots against the directory and plan a supported namespace or domain migration with AD administrators; do not manually rename partition metadata.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
