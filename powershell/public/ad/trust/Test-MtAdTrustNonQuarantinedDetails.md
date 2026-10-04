Non-quarantined external/forest trusts (those without SID filtering) are a significant security risk:

- **SID History Vulnerability**: Attackers can exploit SID history to elevate privileges across trust boundaries
- **Privilege Escalation Path**: Compromised external accounts can gain access to privileged resources
- **Audit Finding**: Most security audits flag non-quarantined external trusts as high-risk
- **Compliance Gap**: Fails compliance requirements for many security frameworks

This test specifically identifies which external and forest trusts lack SID filtering, enabling targeted remediation. Intra-forest (parent-child) trusts are excluded because they do not support quarantine.

#### Control Type

**Preventive**

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

This test derives quarantine status from the `trustAttributes` LDAP attribute (bit `0x4` = `QUARANTINED_DOMAIN`). It filters to external and forest trusts only — intra-forest (parent-child) trusts are excluded because they do not support quarantine. The test displays:

- Target domain of the trust
- Trust direction (Inbound, Outbound, or Bidirectional)
- Trust type (External, Domain, MIT Kerberos, or DCE)
- Quarantine (SID filtering) status

#### Related Tests

- `Test-MtAdTrustQuarantinedCount` - Count of quarantined vs non-quarantined external/forest trusts
- `Test-MtAdTrustInterForestCount` - Identifies external trusts that should be quarantined
- `Test-MtAdTrustDetails` - Complete trust configuration details

#### Related links

- [Microsoft Learn: Security considerations for trusts](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-server-2003/cc755321%28v=ws.10%29)
- [ANSSI Active Directory checkpoints: Unfiltered outbound domain trust relationship](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_trusts_domain_notfiltered)
