function Test-AzdoSSHAuthenticationCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status of the possibility to use SSH keys to connect to Azure DevOps.

    https://aka.ms/vstspolicyssh
    https://learn.microsoft.com/en-us/azure/devops/repos/git/auth-overview?view=azure-devops&source=recommendations&tabs=Windows
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoSSHAuthenticationCompliance
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
    Write-Verbose "Running Test-AzdoSSHAuthentication"


    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection' -Force
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowSecureShell'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your tenant does not allow developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    } else {
        $resultMarkdown = "Your tenant allows developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }


    return $result

}
