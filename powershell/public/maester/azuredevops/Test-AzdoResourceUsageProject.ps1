<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of limitation regarding projects in Azure DevOps, As it supports up to 1,000 projects within an organization

    https://learn.microsoft.com/en-us/azure/devops/organizations/projects/about-projects?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoResourceUsageProject
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoResourceUsageProject
#>
function Test-AzdoResourceUsageProject {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-verbose 'Not connected to Azure DevOps'

    $Projects = (Get-ADOPSResourceUsage).Projects

    $CurrentUsage = $($Projects.count / $Projects.limit).Tostring("P")

    if ($($Projects.count / $Projects.limit) -gt 0.9) {
        $resultMarkdown = "Project Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    } else {
        $resultMarkdown = "Well done. Project Resource Usage limit is at $CurrentUsage"
        $result = $true
    }

    Add-MtTestResultDetail -Result $resultMarkdown -Severity 'High'

    return $result
}
