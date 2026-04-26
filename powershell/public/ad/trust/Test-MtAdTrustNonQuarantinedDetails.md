#### Test-MtAdTrustNonQuarantinedDetails

#### Why This Test Matters

Non-quarantined trusts (those without SID filtering) are a significant security risk:

- **SID History Vulnerability**: Attackers can exploit SID history to elevate privileges across trust boundaries
- **Privilege Escalation Path**: Compromised external accounts can gain access to privileged resources
- **Audit Finding**: Most security audits flag non-quarantined external trusts as high-risk
- **Compliance Gap**: Fails compliance requirements for many security frameworks

This test specifically identifies which trusts lack SID filtering, enabling targeted remediation.

#### Security Recommendation

**Immediate Actions:**
- Review each non-quarantined trust to determine if SID filtering can be enabled
- Test applications that rely on cross-trust authentication before enabling SID filtering
- Enable SID filtering on all inter-forest trusts where possible

**Long-term Strategy:**
- Replace external trusts with forest trusts where possible
- Implement selective authentication for sensitive resources
- Regularly audit trust configurations
- Document any trusts that must remain non-quarantined with business justification

**Command to Enable SID Filtering:**
```powershell
Set-ADTrust -Target <TrustName> -Quarantine $true
```

#### How the Test Works

This test filters trust objects where `Quarantined` is `$false` and displays:

- Target domain of the trust
- Trust direction (Inbound, Outbound, or Bidirectional)
- Whether it's an intra-forest or inter-forest trust
- Trust type (External, Forest, or Kerberos)

#### Related Tests

- `Test-MtAdTrustQuarantinedCount` - Count of quarantined vs non-quarantined trusts
- `Test-MtAdTrustInterForestCount` - Identifies external trusts that should be quarantined
- `Test-MtAdTrustDetails` - Complete trust configuration details
