function Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepoCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status if creation of Team Foundation Version Control (TFVC) repositories is disabled.

    https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepoCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo"


    $result = (Get-ADOPSOrganizationRepositorySettings -Force | Where-object key -eq "DisableTfvcRepositories").value

    if ($result) {
        $resultMarkdown = "Team Foundation Version Control (TFVC) repositories cannot be created."
    } else {
        $resultMarkdown = "Team Foundation Version Control (TFVC) can be created."
    }


    return $result

}
