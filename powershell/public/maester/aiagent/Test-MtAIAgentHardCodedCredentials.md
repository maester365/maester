AI agents should not have hard-coded credentials in topic definitions.

Hard-coded credentials such as API keys, bearer tokens, connection strings, or passwords embedded in agent topics can be extracted through prompt injection attacks. These credentials often persist in agent definitions long after they have been rotated elsewhere, creating a window of exposure.

### How to fix

Replace all hard-coded credentials with secure alternatives. Use Power Platform environment variables for configuration values and Azure Key Vault for secrets. Configure custom connectors with proper OAuth or API key authentication that stores credentials outside the agent topic definition.

Learn more: [Use environment variables in Power Platform](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/environmentvariables)

<!--- Results --->
%TestResult%
