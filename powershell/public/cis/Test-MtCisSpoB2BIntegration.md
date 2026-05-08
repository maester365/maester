7.2.2 (L1) Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled

Entra ID B2B provides authentication and management of guests. Authentication happens via one-time passcode when they don't already have a work or school account or a Microsoft account. Integration with SharePoint and OneDrive allows for more granular control of how guest user accounts are managed in the organization's AAD, unifying a similar guest experience already deployed in other Microsoft 365 services such as Teams.

>Note: Global Reader role currently can't access SharePoint using PowerShell.

## Rationale

External users assigned guest accounts will be subject to Entra ID access policies, such as multi-factor authentication. This provides a way to manage guest identities and control access to SharePoint and OneDrive resources. Without this integration, files can be shared without account registration, making it more challenging to audit and manage who has access to the organization's data.

## Impact

B2B collaboration is used with other Entra services so should not be new or unusual. Microsoft also has made the experience seamless when turning on integration on SharePoint sites that already have active files shared with guest users. The referenced Microsoft article on the subject has more details on this.

## Remediation

1. Connect to SharePoint Online using `Connect-SPOService`
2. Run the following command:

```powershell
Set-SPOTenant -EnableAzureADB2BIntegration $true
```

>Default Value: False

## Related Links

* [Enabling the integration](https://learn.microsoft.com/en-us/sharepoint/sharepoint-azureb2b-integration#enabling-the-integration)
* [What is Microsoft Entra B2B collaboration?](https://learn.microsoft.com/en-us/entra/external-id/what-is-b2b)
* [Set-SPOTenant](https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 368](https://www.cisecurity.org/benchmark/microsoft_365)