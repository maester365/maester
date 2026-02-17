7.2.2 (L1) Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled

Before integrating SharePoint Online with Microsoft Entra B2B, external users authenticated via one-time passcode connect directly to SharePoint.
This authentication bypasses all configurations from Microsoft Entra as well as sign-in logs and can only be monitoring in Auditing-logs.

With SharePoint and OneDrive integrated with Microsoft Entra B2B Invitation Manager, invited people outside the organization are each given a guest account in the directory and are subject to Microsoft Entra ID access policies such as conditional access.
Invitations to a SharePoint site use Microsoft Entra B2B and no longer require users to have or create a personal Microsoft account.

## Related Links

* [SharePoint and OneDrive integration with Microsoft Entra B2B | Microsoft Learn](https://learn.microsoft.com/en-us/sharepoint/sharepoint-azureb2b-integration)
* [Secure external sharing recipient experience | Microsoft Learn](https://learn.microsoft.com/en-us/sharepoint/what-s-new-in-sharing-in-targeted-release)
* CIS 7.2.2 (L1) Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled