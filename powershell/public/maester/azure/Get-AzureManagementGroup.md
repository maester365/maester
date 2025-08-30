# Get Azure Management Groups

This function retrieves all Azure Management Group names by querying the Azure Management API. Returns an array of management group names that are accessible to the current user.

#### Usage

This is a helper function used by other Maester tests that need to interact with Azure Management Groups. It returns all management group names in the tenant.

#### Prerequisites

- Azure PowerShell connection with appropriate permissions to read management groups
- Access to the Azure Resource Manager API

#### Related links

* [Quickstart: Create a management group](https://learn.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal)
* [Azure Management Groups Overview](https://docs.microsoft.com/en-us/azure/governance/management-groups/overview)

<!--- Results --->
%TestResult%
