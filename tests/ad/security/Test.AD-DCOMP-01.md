Unconstrained delegation on non-domain-controller computers exposes users' Kerberos tickets to any attacker who compromises the computer. This check fails when one or more non-DC computers have the `TrustedForDelegation` flag. DCs are counted separately but do not cause failure; percentages use only non-DC computers as the denominator.

**Security Risks:**
- **Complete Impersonation**: Attackers can impersonate any user who authenticates to the computer
- **Lateral Movement**: Compromising one computer with unconstrained delegation enables access to all domain resources
- **Privilege Escalation**: Can be used to escalate from standard user to domain admin
- **Ticket Theft**: Attackers can harvest TGTs from memory on these computers

#### Control Type

**Operational**

#### Security Recommendation

1. **Eliminate unconstrained delegation**:
   - Replace with constrained delegation or resource-based constrained delegation
   - Audit all computers with this setting
   - Prioritize non-DC computers for remediation

2. **Protect computers that require delegation**:
   - Limit to absolute minimum necessary
   - Place in isolated OU with strict access controls
   - Monitor for compromise indicators

3. **Use alternatives**:
   - **Constrained Delegation**: Limits impersonation to specific services
   - **Resource-Based Constrained Delegation**: More flexible and secure approach
   - **Protocol Transition**: When combined with constrained delegation

#### How the Test Works

This test counts computers with the `TrustedForDelegation` flag enabled and categorizes them by:
- Domain Controllers vs. non-DC computers
- Total count and percentage

#### Related Tests

- `AD-DCOMP-03` - Reviews protocol transition on non-DC computers
- `Test-MtAdUserDelegationConfiguredCount` - Reviews user account delegation

#### Related links

- [Microsoft Defender for Identity: Unsecure Kerberos delegation](https://learn.microsoft.com/defender-for-identity/security-posture-assessments/accounts#unsecure-kerberos-delegation)
- [ANSSI Active Directory checkpoints: Unconstrained authentication delegation](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_delegation_t4d)

<!--- Results --->
%TestResult%
