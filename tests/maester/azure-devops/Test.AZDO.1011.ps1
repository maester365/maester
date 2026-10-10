<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of limitation regarding projects in Azure DevOps, As it supports up to 1,000 projects within an organization

    https://learn.microsoft.com/azure/devops/organizations/projects/about-projects?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoResourceUsageProject
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoResourceUsageProject
#>
function Test-AzdoResourceUsageProject {
    [MaesterTest(
        Id = 'AZDO.1011',
        Title = 'Project Resource Limits.',
        Severity = 'Info',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/organizations/projects/about-projects?view=azure-devops'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoResourceUsageProject"

$Projects = (Get-ADOPSResourceUsage -Force).Projects

    $CurrentUsage = $($Projects.count / $Projects.limit).ToString("P")

    if ($($Projects.count / $Projects.limit) -gt 0.9) {
        $resultMarkdown = "Project Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    } else {
        $resultMarkdown = "Project Resource Usage limit is at $CurrentUsage"
        $result = $true
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
