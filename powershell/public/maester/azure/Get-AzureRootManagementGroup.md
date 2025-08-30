# Get Azure Tenant Root Management Group ID

This function retrieves the Azure Tenant Root Management Group ID by querying all management groups and finding the one with the display name "Tenant Root Group".

#### Usage

This is a helper function used by other Maester tests that need to interact with Azure Management Groups at the tenant level.

#### Prerequisites

- Azure PowerShell connection with appropriate permissions to read management groups
- Access to the Azure Resource Manager API

#### Related links

* [Quickstart: Create a management group](https://learn.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal)
* [Azure Management Groups Overview](https://docs.microsoft.com/en-us/azure/governance/management-groups/overview)

<!--- Results --->
%TestResult%
