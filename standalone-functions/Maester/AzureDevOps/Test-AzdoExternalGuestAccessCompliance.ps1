function Test-AzdoExternalGuestAccessCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the configuration of external guest access to Azure DevOps.

    https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops#manage-external-guest-access
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoExternalGuestAccessCompliance
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
    Write-Verbose "Running Test-AzdoExternalGuestAccess"


    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User' -Force
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.DisallowAadGuestUserAccess'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your tenant has restricted external guest access to your Azure DevOps organization."
    } else {
        $resultMarkdown = "External user(s) can be added to the organization to which they were invited and have immediate access. A guest user can add other guest users to the organization after being granted the Guest Inviter role in Microsoft Entra ID."
    }


    return $result

}
