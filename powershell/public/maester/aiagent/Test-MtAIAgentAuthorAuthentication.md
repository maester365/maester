AI agents should not use author (maker) authentication for their connector tools.

When a connector tool uses **author authentication**, the agent accesses external services (SharePoint, SQL, Outlook, etc.) using the authors stored credentials instead of requiring the end user to authenticate. This creates a **privilege escalation** risk — the agent operates with the maker's full permissions regardless of who is chatting with it, and it bypasses separation of duties controls.

### How to fix

In Copilot Studio, review the agent's tools and change each connector's authentication setting from **Agent author authentication** to **User authentication**. This ensures the agent accesses external services using the chatting user's own credentials and permission scope.

Learn more: [Configure user authentication in Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/configure-enduser-authentication)

<!--- Results --->
%TestResult%
