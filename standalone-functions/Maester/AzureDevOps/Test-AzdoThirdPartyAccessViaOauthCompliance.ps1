function Test-AzdoThirdPartyAccessViaOauthCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of Third-party application access via OAuth.

    https://aka.ms/vstspolicyoauth
    https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/azure-devops-oauth?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoThirdPartyAccessViaOauthCompliance
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
    Write-Verbose "Running Test-AzdoThirdPartyAccessViaOauth"


    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection' -Force
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowOAuthAuthentication'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your tenant has restricted Azure DevOps OAuth apps from accessing resources in your organization through OAuth."
    } else {
        $resultMarkdown = "Your tenant has not restricted Azure DevOps OAuth apps from accessing resources in your organization through OAuth."
    }


    return $result

}
