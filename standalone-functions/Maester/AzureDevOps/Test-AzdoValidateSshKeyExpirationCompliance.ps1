function Test-AzdoValidateSshKeyExpirationCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if SSH key expiration validation is configured.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#ssh-key-policies
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoValidateSshKeyExpirationCompliance
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
    Write-Verbose "Running Test-AzdoValidateSshKeyExpiration"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -Force
    $Policy = $SecurityPolicies | where-object -property name -eq 'Policy.ValidateSshKeyExpiration'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant has SSH key expiration validation enabled."
    } else {
        $resultMarkdown = "Your tenant does not have SSH key expiration validation enabled."
    }


    return $result

}
