AI agents should not send email with AI-controlled inputs.

Agents configured with email-sending tools (such as Office 365 Outlook connectors) where the recipient, subject, or body can be influenced by AI-generated content present a data exfiltration risk. An attacker could craft prompts that cause the agent to send sensitive organizational data to external addresses.

### How to fix

Remove email-sending tools from agents that do not have a legitimate business need to send email. For agents that do require email capabilities, ensure recipients are restricted to a fixed list and are not dynamically determined by user input or AI-generated content. Use DLP policies to block the Outlook connector for agents that should not send email.

Learn more: [Configure data policies for agents](https://learn.microsoft.com/microsoft-copilot-studio/admin-data-loss-prevention?tabs=webapp#configure-a-data-policy-in-the-power-platform-admin-center)

<!--- Results --->
%TestResult%
