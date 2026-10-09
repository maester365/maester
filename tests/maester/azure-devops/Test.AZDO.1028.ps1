<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if creation of Team Foundation Version Control (TFVC) repositories is disabled.

    https://learn.microsoft.com/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects

.EXAMPLE
    ```
    Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo
#>
function Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo {
    [MaesterTest(
        Id = 'AZDO.1028',
        Title = 'Disable creation of TFVC repositories.',
        Severity = 'Medium',
        Category = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo"

$result = (Get-ADOPSOrganizationRepositorySettings -Force | Where-object key -eq "DisableTfvcRepositories").value

    if ($result) {
        $resultMarkdown = "Team Foundation Version Control (TFVC) repositories cannot be created."
    } else {
        $resultMarkdown = "Team Foundation Version Control (TFVC) can be created."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
