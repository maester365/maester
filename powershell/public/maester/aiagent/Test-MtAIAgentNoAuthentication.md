AI agents should require user authentication with sign-in enforced.

This test flags two issues:
- **No authentication**: Agents configured without any authentication allow anonymous access.
- **Sign-in not required**: Agents with authentication configured but "Require users to sign in" toggled off. This means users can interact with the agent without authenticating, undermining the auth configuration.

### How to fix

1. In Copilot Studio, open the agent settings and configure authentication to use **Authenticate with Microsoft** or **Authenticate manually**.
2. Enable **Require users to sign in** to ensure every user authenticates before interacting with the agent.

Learn more: [Configure user authentication in Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/configuration-end-user-authentication#required-user-sign-in-and-agent-sharing)

<!--- Results --->
%TestResult%
