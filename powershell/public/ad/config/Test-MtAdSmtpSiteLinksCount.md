#### Test-MtAdSmtpSiteLinksCount

#### Why This Test Matters
SMTP site links are a replication transport mechanism used in AD. They’re considered rare and mostly legacy/compatibility-oriented; many modern environments rely on RPC over IP (or other supported transports) rather than SMTP.

Using SMTP replication can be less secure and more difficult to harden than standard transports, depending on network controls, email path hardening, and endpoint exposure.

Monitoring SMTP site link *count* helps detect:
- Unexpected SMTP replication configuration (often a sign of misconfiguration or old legacy settings being retained)
- Potential exposure of replication paths through email-based infrastructure

#### Security Recommendation
- Prefer RPC/IP (or other supported modern transports) and remove unnecessary SMTP site links.
- If SMTP must remain (legacy reasons), ensure you have strong network controls, hardened mail flow paths, and strict access rules.
- Periodically review replication transport configuration and validate it matches security baselines.

#### How the Test Works
The test queries AD site link configuration entries that use SMTP as the replication transport and returns the number of such SMTP site links.
