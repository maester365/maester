AI agents should not use MCP server tools without review.

Model Context Protocol (MCP) tools extend agent capabilities by connecting to external servers. These integrations introduce supply chain risks — if an MCP server is compromised, tools-poisoned or untrusted, it could provide malicious instructions, exfiltrate data, or execute unauthorized actions through the agent.

### How to fix

Review all MCP server integrations in the flagged agents. Ensure each MCP server endpoint is owned by your organization or a trusted partner, is hosted on infrastructure you control, and uses HTTPS with proper authentication. Consider replacing MCP tools with Power Platform custom connectors that provide DLP policy enforcement and governance controls.

Learn more: [Use MCP servers in Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp)

<!--- Results --->
%TestResult%
