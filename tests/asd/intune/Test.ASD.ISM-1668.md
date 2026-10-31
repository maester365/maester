Microsoft Office is blocked from creating executable content (ISM-1668, Essential Eight Maturity Level Two, User application hardening).

A macro that writes an executable, script or DLL to disk is staging malware for a later step. Blocking Office from creating executable content stops the drop even when the macro itself was allowed to run. This check reads the attack surface reduction rules of every Intune Windows configuration policy (Endpoint security and settings catalog policies share the same setting definitions) and passes when assigned policies set both **Block Office applications from creating executable content** and **Block executable content from email client and webmail** to **Block**. Attachments opened from Outlook and webmail are covered by their own rule, so ASD's assessment process guide asks for both. Audit and Warn only report the behaviour and do not satisfy the control.

The check confirms that a policy has an inclusion assignment. It does not verify assignment coverage or exclusions, conflicting policies, or the effective settings on devices.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Endpoint security** > **[Attack surface reduction](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/asr)** and open your attack surface reduction rules policy, or create one for **Windows** with the profile **Attack Surface Reduction Rules**.
2. Set **Block Office applications from creating executable content** and **Block executable content from email client and webmail** to **Block**. Pilot the rule in **Audit** first if Office add-ins or line-of-business macros are in use.
3. Assign the policy to all workstations.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Essential Eight assessment process guide](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-assessment-process-guide)
* [Attack surface reduction rules reference](https://learn.microsoft.com/defender-endpoint/attack-surface-reduction-rules-reference)
* [ISM Guidelines for system hardening](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-hardening)

<!--- Results --->
%TestResult%
