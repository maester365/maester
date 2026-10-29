Microsoft Office is blocked from creating child processes (ISM-1667, Essential Eight Maturity Level Two, User application hardening).

A malicious document rarely does its damage inside Word or Excel: it launches PowerShell, cmd.exe or a downloaded executable. Blocking Office from starting child processes cuts that chain whatever the macro, exploit or DDE payload tried. This check reads the attack surface reduction rules of every Intune Windows configuration policy (Endpoint security and settings catalog policies share the same setting definitions) and passes when assigned policies set both **Block all Office applications from creating child processes** and **Block Office communication application from creating child processes** to **Block**. Outlook is covered by its own rule, so ASD's assessment process guide asks for both. Audit and Warn only report the behaviour and do not satisfy the control.

The check confirms that a policy has an inclusion assignment. It does not verify assignment coverage or exclusions, conflicting policies, or the effective settings on devices.

#### Remediation action

1. In **Microsoft Intune admin center**, go to **Endpoint security** > **[Attack surface reduction](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/asr)** and open your attack surface reduction rules policy, or create one for **Windows** with the profile **Attack Surface Reduction Rules**.
2. Set **Block all Office applications from creating child processes** and **Block Office communication application from creating child processes** to **Block**. Pilot the rule in **Audit** first if Office add-ins or line-of-business macros are in use.
3. Assign the policy to all workstations.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Essential Eight assessment process guide](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-assessment-process-guide)
* [Attack surface reduction rules reference](https://learn.microsoft.com/defender-endpoint/attack-surface-reduction-rules-reference)
* [ISM Guidelines for system hardening](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-hardening)

<!--- Results --->
%TestResult%
