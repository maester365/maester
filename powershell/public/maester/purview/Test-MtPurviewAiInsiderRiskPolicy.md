Ensure a Microsoft Purview Insider Risk Management policy from the **Risky AI usage** template is enabled so risky Microsoft 365 Copilot and AI-app interactions generate triageable alerts.

The Risky AI usage template detects:

- Prompts attempting to **jailbreak** or bypass system prompts.
- Prompts attempting to **extract or summarise sensitive content** that falls under DLP / SIT signals.
- Generation of **harmful, unethical or otherwise risky** AI responses.
- High-volume / anomalous AI-interaction patterns from individual users.

Without a Risky AI usage policy enabled, these signals are silently lost — Insider Risk reviewers will have no triage queue for AI misuse, and DSPM for AI cannot escalate risky users into Insider Risk Management workflows.

The test requires Microsoft 365 E5 or the Insider Risk Management add-on. The test will skip cleanly on tenants that do not license IRM (cmdlet `Get-InsiderRiskPolicy` is unavailable).

The test passes when at least one Insider Risk policy with an AI-related scenario / template is enabled.

#### Remediation action:

1. Open the [Microsoft Purview portal — Insider Risk Management — Policies](https://purview.microsoft.com/insiderriskmgmt/policies).
2. Click **+ Create policy**.
3. Choose the **Risky AI usage** template (under the AI / Generative AI category).
4. Define users in scope (typically all users or a pilot group), reviewers, and any indicator thresholds.
5. **Enable** the policy and confirm: `Get-InsiderRiskPolicy | Where-Object { $_.InsiderRiskScenario -match 'AI' -and $_.Enabled }`.

> **Tip:** Enable Adaptive Protection so that risky AI users automatically pick up stricter DLP / Conditional Access policies once they cross a risk threshold.

#### Related links

- [Microsoft Learn — Insider Risk Management policies](https://learn.microsoft.com/en-us/purview/insider-risk-management-policies)
- [Microsoft Learn — Detect risky use of AI with Insider Risk Management](https://learn.microsoft.com/en-us/purview/insider-risk-management-policy-templates)
- [Microsoft Learn — Microsoft Purview AI Hub & DSPM for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)

<!--- Results --->
%TestResult%
