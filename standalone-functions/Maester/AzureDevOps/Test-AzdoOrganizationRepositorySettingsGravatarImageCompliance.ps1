function Test-AzdoOrganizationRepositorySettingsGravatarImageCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status if Gravatar images are shown for users outside of your enterprise.

    https://learn.microsoft.com/en-us/azure/devops/repos/git/repository-settings?view=azure-devops&tabs=browser#gravatar-images
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationRepositorySettingsGravatarImageCompliance
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
    Write-Verbose "Running Test-AzdoOrganizationRepositorySettingsGravatarImage"


    $result = (Get-ADOPSOrganizationRepositorySettings -Force | Where-object key -eq "GravatarEnabled").value

    if (-not $result) {
        $resultMarkdown = "Gravatar images are not exposed outside of your enterprise."
    } else {
        $resultMarkdown = "Gravatar images are exposed for users outside of your enterprise."
    }


    return $result

}
