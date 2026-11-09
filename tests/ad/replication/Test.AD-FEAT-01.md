This inventory shows which Active Directory optional features are available and which are enabled, including their enabled scopes. It combines the former feature-count and enabled-feature-detail inventories (AD-CFG-04 and AD-FEAT-02). A feature's existence does not mean it has been enabled.

#### Control Type

**Operational**

#### Security Recommendation

Document optional features and review their enabled scopes with administrators; never enable a feature solely to improve an inventory count.

#### How the Test Works

The check enumerates collected optional feature names, counts enabled features and reports the scopes where each is enabled. Availability and enablement are separate observations, not a security pass/fail judgement.

#### Related Tests

- **AD-FOR-04 — Active Directory Recycle Bin should be enabled** — `Test-MtAdRecycleBinStatus` — Evaluates Recycle Bin status separately from feature inventory.

#### Remediation action

Review feature names and enabled scopes against your forest's intended configuration before changing any optional feature. Enabling an optional feature may be irreversible. To evaluate whether the Recycle Bin is enabled, use AD-FOR-04; this inventory does not give its status a separate pass/fail result.

#### Related links

- [Microsoft: enable the Active Directory Recycle Bin](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/advanced-ad-ds-management-using-active-directory-administrative-center--level-200-)

<!--- Results --->
%TestResult%
