# Test-MtAdIpSiteLinksCount

## Why This Test Matters
IP site links are the standard replication transport for Active Directory. They typically use direct network communication (e.g., RPC over IP) that can be secured with conventional network controls, firewall rules, and monitoring.

Monitoring the IP site link *count* helps ensure your replication topology is using the intended, more controllable transport mechanism and highlights drift where legacy or less secure transports might be taking precedence.

This test helps answer:
- Are there the expected number of IP site links?
- Is replication configuration moving away from the preferred transport?

## Security Recommendation
- Ensure replication uses IP-based transports wherever possible.
- Keep firewall rules tight between domain controllers and validate required ports/paths.
- Compare IP site link configuration against your designed replication topology; investigate unexpected changes.

## How the Test Works
The test queries AD site link configuration entries using IP as the replication transport and returns the number of IP-based site links.

## Related Tests
- [Test-MtAdSmtpSiteLinksCount](./Test-MtAdSmtpSiteLinksCount.md)
