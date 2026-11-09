**SPN mappings** (`sPNMappings` on the Directory Service object) map service classes such as HTTP and CIFS to the HOST service class for Kerberos ticket lookup. They do not map clients to realms, and are not individual account `servicePrincipalName` values. Changes may affect service authentication.

- **Authentication inconsistencies** (Kerberos vs. fallback behaviors)
- Clients receiving **unexpected service identity** resolution
- Increased exposure to **credential forwarding / downgrade-style** scenarios if legacy behavior is unintentionally permitted

#### Control Type

**Operational**

#### Security Recommendation
- Review HOST-class service mappings against the organization's supported services before making changes.
- Do not remove a mapping solely because this inventory reports it; doing so can break Kerberos service ticket resolution.

#### How the Test Works
This inventory reports the raw `sPNMappings` entries and count. It does not inspect account SPNs or claim that any mapping is unsafe.

#### Related Tests
- **AD-SPN-01 — Computer SPN service class count should be retrievable** — `Test-MtAdComputerSpnServiceClassCount` — Inventories account-level computer SPNs, a different setting (`servicePrincipalName`).

<!--- Results --->
%TestResult%
