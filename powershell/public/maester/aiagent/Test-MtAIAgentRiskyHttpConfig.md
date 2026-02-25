AI agents should not use risky HTTP configurations.

Agents with HTTP request nodes in topics connecting to non-standard ports or using plain HTTP (instead of HTTPS) may be misconfigured or could indicate data exfiltration or command-and-control communication channels.

### How to fix

Review the HTTP request nodes in each flagged agent's topics. Ensure all HTTP requests use HTTPS on standard port 443. Replace direct HTTP calls with Power Platform connectors where possible, as connectors provide built-in governance and DLP policy enforcement.

Learn more: [Configure data policies for agents](https://learn.microsoft.com/microsoft-copilot-studio/admin-data-loss-prevention?tabs=webapp#block-http-requests)

<!--- Results --->
%TestResult%
