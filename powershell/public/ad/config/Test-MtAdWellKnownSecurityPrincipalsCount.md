#### Test-MtAdWellKnownSecurityPrincipalsCount

#### Why This Test Matters
Well-known security principals are built-in identities with special meaning in Active Directory (for example, principals that Windows and AD components rely on for system behavior). Unexpected changes to these principals can indicate tampering, malicious SID/object replacement, or unauthorized directory modification.

#### Security Recommendation
- Validate that only the expected well-known principals exist (default is **27** for typical configurations).
- Restrict permissions to the container(s) holding well-known principals so only AD administrators can modify them.
- Audit changes by enabling directory change auditing and reviewing security event logs for modifications.
- Investigate any deviation immediately as a potential sign of directory tampering.

#### How the Test Works
- Locates the AD container(s) that store well-known security principal objects.
- Enumerates those objects and counts how many are present.
- Compares the count to the expected baseline (default **27**) and flags any unexpected values.

#### Related Tests
- [Test-MtAdAdActivationObjectsCount](./Test-MtAdAdActivationObjectsCount.md): Detects unexpected AD configuration objects that can reflect tampering.
- [Test-MtAdTrustedRootCaCount](./Test-MtAdTrustedRootCaCount.md): Identifies unauthorized trust anchors that can undermine authentication integrity.
