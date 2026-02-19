<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if creation of Team Foundation Version Control (TFVC) repositories is disabled.

    https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects

.EXAMPLE
    ```
    Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo
#>
function Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
        break
    }

    $result = (Get-ADOPSOrganizationRepositorySettings | Where-object key -eq "DisableTfvcRepositories").value

    if ($result) {
        $resultMarkdown = "Well done. Team Foundation Version Control (TFVC) repositories cannot be created."
    } else {
        $resultMarkdown = "Team Foundation Version Control (TFVC) can be created."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
