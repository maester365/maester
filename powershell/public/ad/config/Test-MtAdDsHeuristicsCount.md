**dSHeuristics** is an AD configuration setting that controls behavior for advanced directory features and legacy compatibility. Because it influences protocol-level behavior (including areas such as LDAP security expectations and feature gating), an incorrect or unexpected dSHeuristics value can:

- Leave AD behaving in a more **legacy/less secure** mode
- Cause authentication and directory access **inconsistencies** across clients
- Increase the likelihood of **unsafe fallback behaviors** when clients interact with AD

#### Control Type

**Operational**

#### Security Recommendation
- Confirm dSHeuristics is set according to your domain’s **hardening baseline** (and any guidance for your forest/domain functional level).
- Avoid “trial-and-error” changes; instead, validate configuration changes in a controlled test window.
- Prioritize alignment with modern security requirements (including enforcing secure LDAP behavior where applicable).

#### How the Test Works
This test queries AD configuration for the dSHeuristics setting(s) and reports a count-style metric indicating how many relevant dSHeuristics values are present/active so you can assess whether the environment matches your expected security baseline.

#### Related Tests
- `Test-MtAdLdapQueryPolicyCount` - Helps ensure LDAP is protected by sane query limits.

#### Related links

- [Microsoft Learn: dSHeuristics attribute (MS-ADTS)](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/e5899be4-862e-496f-9a38-33950617d2c5)
- [ANSSI Active Directory checkpoints: Dangerous dsHeuristics settings](https://www.cert.ssi.gouv.fr/uploads/ad_checklist.html#vuln_dsheuristics_bad)
