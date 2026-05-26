function Test-AzdoOrganizationCreationRestrictionCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if organization creation is restricted.

    Requires Azure DevOps organization backed by a Microsoft Entra tenant and
    Azure DevOps Administrator permissions.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/azure-ad-tenant-policy-restrict-org-creation?view=azure-devops#turn-on-the-policy
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationCreationRestrictionCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoOrganizationCreationRestriction"


    $Policy = Get-ADOPSTenantPolicy -PolicyCategory OrganizationCreationRestriction -Force
    $result = [bool]$Policy.value
    if ($null -eq $Policy) {
        $Message = "Tenant Policy for OrganizationCreationRestriction not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
    }
    else {
        if ($result) {
            $resultMarkdown = "Your tenant has organization creation restricted."
        }
        else {
            $resultMarkdown = "Your tenant does not have organization creation restricted."
        }


        return $result
    }

}
