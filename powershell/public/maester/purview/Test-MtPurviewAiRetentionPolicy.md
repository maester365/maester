Ensure a Microsoft Purview retention policy is configured for the **Microsoft Copilot** location to govern how Microsoft 365 Copilot prompts and AI-generated responses are retained or deleted.

Copilot interactions (the user prompt + the AI response) are stored in the user's Exchange mailbox in a hidden folder and are subject to Purview retention. Without a retention policy targeting the Microsoft Copilot location:

- Copilot transcripts may be retained **indefinitely**, increasing data subject access request and breach blast-radius.
- The organisation may **not satisfy regulatory obligations** that require defensible AI interaction retention or disposal (EU AI Act record-keeping, sector-specific regulations).
- eDiscovery and legal-hold workflows may have inconsistent coverage of AI activity.

Microsoft Purview now exposes Copilot retention through two surfaces:

- **Legacy retention** (`Get-RetentionCompliancePolicy`) — historically used for the *Teams chats and Copilot interactions* location.
- **App retention** (`Get-AppRetentionCompliancePolicy`) — the current surface for **Microsoft Copilot experiences** (Microsoft 365 Copilot, Security Copilot, Copilot Studio, Copilot in Fabric) and **Enterprise AI apps**, with application identifiers such as `User:M365Copilot`.

The test passes when at least one enabled Microsoft Purview retention policy targets Microsoft Copilot interactions on **either** surface.

#### Remediation action:

1. Open the [Microsoft Purview portal — Data Lifecycle Management — Policies](https://purview.microsoft.com/datalifecyclemanagement/policies).
2. Click **+ New retention policy**.
3. Choose the locations and enable **Microsoft Copilot** (under the AI category).
4. Define a retention duration (for example, retain for 1 year then delete) aligned to your regulatory and records-retention strategy.
5. Apply to all users or scoped pilot groups, and turn the policy on.
6. Verify with PowerShell, checking both surfaces:

   ```powershell
   Connect-IPPSSession
   Get-RetentionCompliancePolicy | Where-Object { $_.MicrosoftCopilotLocation -or $_.Workload -match 'Copilot' }
   Get-AppRetentionCompliancePolicy | Where-Object { $_.Workload -match 'Copilot' -or ($_.Applications | Out-String) -match 'Copilot' -or ($_.Locations | Out-String) -match 'Copilot' }
   ```

#### Related links

- [Microsoft Learn — Retention policies for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/purview/retention-policies-copilot)
- [Microsoft Learn — Learn about retention](https://learn.microsoft.com/en-us/purview/retention)
- [Microsoft Learn — Audit and eDiscovery for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/purview/audit-copilot)

<!--- Results --->
%TestResult%
