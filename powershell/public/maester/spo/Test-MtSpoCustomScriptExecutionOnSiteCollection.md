7.3.4 (L1) Ensure custom script execution is restricted on site collections

Description:
This setting controls custom script execution on a particular site (previously called "site collection").
Custom scripts can allow users to change the look, feel and behavior of sites and pages. Every script that runs in a SharePoint page (whether it's an HTML page in a document library or a JavaScript in a Script Editor Web Part) always runs in the context of the user visiting the page and the SharePoint application. This means:
* Scripts have access to everything the user has access to.
* Scripts can access content across several Microsoft 365 services and even
beyond with Microsoft Graph integration. The recommended state is DenyAddAndCustomizePages set to $true.

Rationale:
Custom scripts could contain malicious instructions unknown to the user or administrator. When users are allowed to run custom script, the organization can no longer enforce governance, scope the capabilities of inserted code, block specific parts of code, or block all custom code that has been deployed. If scripting is allowed the following things can't be audited:
* What code has been inserted
* Where the code has been inserted
* Who inserted the code

Note: Microsoft recommends using the SharePoint Framework instead of custom scripts

## Related Links

* [Allow or prevent custom script | Microsoft Learn](https://learn.microsoft.com/en-us/sharepoint/allow-or-prevent-custom-script)
* CIS 7.3.4 (L1) Ensure custom script execution is restricted on site collections