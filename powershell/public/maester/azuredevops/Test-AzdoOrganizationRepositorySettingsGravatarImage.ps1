<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if Gravatar images are shown for users outside of your enterprise.

    https://learn.microsoft.com/en-us/azure/devops/repos/git/repository-settings?view=azure-devops&tabs=browser#gravatar-images

.EXAMPLE
    ```
    Test-AzdoOrganizationRepositorySettingsGravatarImage
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationRepositorySettingsGravatarImage
#>
function Test-AzdoOrganizationRepositorySettingsGravatarImage {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
        break
    }

    $result = (Get-ADOPSOrganizationRepositorySettings | Where-object key -eq "GravatarEnabled").value

    if ($result) {
        $resultMarkdown = "Gravatar images are exposed for users outside of your enterprise."
    } else {
        $resultMarkdown = "Well done. Gravatar images are not exposed outside of your enterprise."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
