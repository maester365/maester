This check inventories three separate indicators on non-domain-controller computers and sMSA, gMSA and dMSA accounts: classic Kerberos constrained delegation (KCD) target SPNs from `msDS-AllowedToDelegateTo`, the `TrustedToAuthForDelegation` protocol-transition flag, and **presence** of an `msDS-AllowedToActOnBehalfOfOtherIdentity` resource-based constrained delegation (RBCD) descriptor. One account can have multiple indicators. Descriptor presence neither identifies allowed principals nor proves effective delegation permissions.

**Security Considerations:**
- **Limited Scope**: Safer than unconstrained but still enables impersonation
- **Configuration Complexity**: Easy to misconfigure and accidentally grant excessive permissions
- **Attack Surface**: Each computer with constrained delegation expands the attack surface
- **Legacy Protocol**: Some implementations may fall back to less secure methods

#### Control Type

**Operational**

#### Security Recommendation

1. **Minimize Usage**:
   - Use only where absolutely necessary
   - Regular review of all constrained delegation configurations
   - Document business justification for each instance

2. **Secure Configuration**:
   - Limit to specific SPNs (Service Principal Names)
   - Use protocol transition only when required
   - Regular auditing of delegation settings

3. **Consider Modern Alternatives**:
   - **Resource-Based Constrained Delegation**: More flexible and easier to manage
   - **Group Managed Service Accounts (gMSA)**: Automatic password management
   - **Managed Identity**: For cloud and hybrid scenarios

#### How the Test Works

The test reports device and managed-account populations separately, then combined non-DC account counts for KCD targets, protocol transition and RBCD descriptor presence. Indicator percentages use this combined population. DC identity comes from the DC inventory, not a claimed primary group. A present RBCD descriptor needs a separate permissions review; this test cannot resolve principals or effective access. Delegation on ordinary user accounts remains outside this inventory.

#### Related Tests

- **AD-DCOMP-01 — Non-DC computers and managed service accounts should not have unconstrained delegation** — `Test-MtAdComputerUnconstrainedDelegationCount` — Reviews unconstrained delegation separately.

#### Related links

- [Microsoft Defender for Identity: Unsecure Kerberos delegation](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-kerberos-delegation)
- [ANSSI Active Directory checkpoints: Constrained authentication delegation to privileged service](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_delegation_a2d2)
- [ANSSI Active Directory checkpoints: Constrained delegation with protocol transition to a privileged service](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_delegation_t2a4d)

<!--- Results --->
%TestResult%
