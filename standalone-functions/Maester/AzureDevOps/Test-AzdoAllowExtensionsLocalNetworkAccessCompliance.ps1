function Test-AzdoAllowExtensionsLocalNetworkAccessCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks if extensions are allowed to access resources on the local network.

    https://learn.microsoft.com/en-us/azure/devops/marketplace/allow-extensions-local-network?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoAllowExtensionsLocalNetworkAccessCompliance
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
    Write-Verbose "Running Test-AzdoAllowExtensionsLocalNetworkAccess"


    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.AllowExtensionsLocalNetworkAccess'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your organization allows extensions to access resources on the local network."
    } else {
        $resultMarkdown = "Your organization does not allow extensions to access resources on the local network."
    }


    return $result

}
