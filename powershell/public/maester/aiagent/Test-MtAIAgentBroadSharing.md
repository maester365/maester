AI agents should not be shared broadly with unrestricted access.

Agents with access control set to **Any** or **Any multitenant** can be accessed by anyone, including users outside your organization. This increases the risk of data exposure and unauthorized use of connected systems.

### How to fix

In Copilot Studio, go the agents overview and click on the three dots (`...`) and "share". From here, select "My organization" and make sure it's set to **No permissions, unless specified**. Then, in the specific agents settings, go to "Security" and "Authentication" and make sure "Multi-tenant support" is toggled **off**.

Learn more: [Control how agents are shared](https://learn.microsoft.com/microsoft-copilot-studio/admin-sharing-controls-limits) and [share agents with other users](https://learn.microsoft.com/microsoft-copilot-studio/admin-share-bots?tabs=web)

<!--- Results --->
%TestResult%
