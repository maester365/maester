function Test-AzdoDisableGlobalPATCreationCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if global Personal Access Token creation is restricted.

    Requires Azure DevOps organization backed by a Microsoft Entra tenant and
    Azure DevOps Administrator permissions.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoDisableGlobalPATCreationCompliance
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
    Write-Verbose "Running Test-AzdoDisableGlobalPATCreation"


    $Policy = Get-ADOPSTenantPolicy -PolicyCategory RestrictGlobalPersonalAccessToken -Force

    if ($null -eq $Policy) {
        $Message = "Tenant Policy for RestrictGlobalPersonalAccessToken not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
    }
    else {
        $result = [bool]$Policy.value
        if ($result) {
            $resultMarkdown = "Your tenant has Global Personal Access Token creation disabled."
        }
        else {
            $resultMarkdown = "Your tenant does not have Global Personal Access Token creation disabled."
        }

        return $result
    }


}
