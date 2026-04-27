Ensure Microsoft Purview sensitivity labels are published to users and at least one published label is scoped to **files**, so Microsoft 365 Copilot honors and inherits labels onto AI-generated content.

Microsoft 365 Copilot only:

- **Honors** sensitivity labels (respecting encryption and usage rights from labelled source files).
- **Inherits** the most restrictive label from the source files used to generate a response onto the new generated content.

…**when** sensitivity labels are actually published to users in your tenant. If no label policy is published, or no published label is scoped to files (SharePoint, OneDrive, Office documents), Copilot has no labelling signal to apply, and DSPM for AI cannot report on label-based oversharing risks.

The test passes when:

- At least one **label policy** is published / enforced (`Get-LabelPolicy`).
- At least one **label** has the `File` scope (`Get-Label` where `ContentType` includes `File`).

#### Remediation action:

1. Open the [Microsoft Purview portal — Information Protection — Labels](https://purview.microsoft.com/informationprotection/labels).
2. Create or edit a sensitivity label and ensure **Files** is selected under "Define the scope for this label".
3. Open **Label policies** and publish the label to the relevant users or groups.
4. Verify with PowerShell after a few minutes:
   ```powershell
   Connect-IPPSSession
   Get-LabelPolicy | Where-Object { $_.Mode -eq 'Enforce' }
   Get-Label | Where-Object { $_.ContentType -match 'File' }
   ```

#### Related links

- [Microsoft Learn — Sensitivity labels overview](https://learn.microsoft.com/en-us/purview/sensitivity-labels)
- [Microsoft Learn — Microsoft 365 Copilot data protection and sensitivity labels](https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-privacy)
- [Microsoft Learn — How Copilot inherits sensitivity labels](https://learn.microsoft.com/en-us/purview/sensitivity-labels-coauthoring)

<!--- Results --->
%TestResult%
