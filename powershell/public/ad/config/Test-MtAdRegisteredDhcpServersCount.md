#### Test-MtAdRegisteredDhcpServersCount

#### Why This Test Matters
DHCP servers registered in Active Directory are authorized to provide IP addresses to clients. If unauthorized DHCP servers are registered (or legitimate servers are removed), clients may receive incorrect network settings, experience instability, or be exposed to man-in-the-middle attacks via rogue DHCP.

#### Security Recommendation
- Maintain a strict allowlist of approved DHCP servers and ensure only those servers are registered in AD.
- Remove stale/unneeded DHCP server registrations as part of routine hygiene.
- Restrict permissions for DHCP registration operations to only the DHCP administrators and automation workflows you trust.
- Alert on any change in the number of registered DHCP servers.

#### How the Test Works
- Searches Active Directory for directory objects representing authorized/registered DHCP servers.
- Counts the number of such registered server objects.
- Compares the count to an environment baseline and flags unexpected additions/removals.

#### Related Tests
- [Test-MtAdWellKnownSecurityPrincipalsCount](./Test-MtAdWellKnownSecurityPrincipalsCount.md): Helps confirm AD identity integrity.
- [Test-MtAdEnterpriseCaCount](./Test-MtAdEnterpriseCaCount.md): Complements service authorization checks for certificate infrastructure.
