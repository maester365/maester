Ensure a Microsoft Purview Data Loss Prevention (DLP) policy is configured for the **Microsoft 365 Copilot** location, so Copilot is blocked from summarising or surfacing files containing sensitive information types or labelled content the requesting user has access to but should not have AI summarise.

Microsoft 365 Copilot acts on every file, message and meeting that the requesting user can read. Without a DLP policy targeting the Copilot location, Copilot can:

- Summarise files containing **PII, PCI, PHI, secrets or other regulated data**.
- Paraphrase content from labelled documents in chat / Word / PowerPoint generations.
- Expose oversharing risk in OneDrive / SharePoint at AI speed.

A DLP policy on the Copilot location lets you block Copilot interactions involving files that match SITs or have specific sensitivity labels — without disabling Copilot for the user entirely.

The test passes when at least one **enabled, non-simulation** DLP policy targets the Microsoft 365 Copilot location.

#### Remediation action:

1. Open the [Microsoft Purview portal — Data Loss Prevention — Policies](https://purview.microsoft.com/datalossprevention/policies).
2. Click **+ Create policy** and choose a Custom or template-based DLP policy.
3. Under **Locations**, enable **Microsoft 365 Copilot** (you may also enable Exchange / SharePoint / OneDrive / Devices alongside).
4. Configure rules — for example, match sensitive information types (Credit Card, SSN, customer-specific SITs) or sensitivity labels (Confidential, Highly Confidential).
5. Choose actions — block Copilot from processing the matched file, notify the user, or generate an alert.
6. Set **Mode = Turn the policy on immediately** (avoid leaving it in test/simulation mode for production protection).
7. Verify with: `Get-DlpCompliancePolicy | Where-Object { $_.MicrosoftCopilotLocation -or $_.Workload -match 'Copilot' }`.

#### Related links

- [Microsoft Learn — DLP for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/purview/dlp-microsoft365-copilot-learn-about)
- [Microsoft Learn — Create a DLP policy](https://learn.microsoft.com/en-us/purview/dlp-create-deploy-policy)
- [Microsoft Learn — Microsoft 365 Copilot oversharing assessment](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)

<!--- Results --->
%TestResult%
