<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of the usage of tag definitions in Azure DevOps, as Azure DevOps supports up to 150,000 tag definitions per organization or collection.

    https://learn.microsoft.com/en-us/azure/devops/organizations/settings/work/object-limits?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoResourceUsageWorkItemTag
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoResourceUsageWorkItemTag
#>
function Test-AzdoResourceUsageWorkItemTag {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-verbose 'Not connected to Azure DevOps'

    $WorkItemTags = (Get-ADOPSResourceUsage).'Work Item Tags'

    $CurrentUsage = $($WorkItemTags.count / $WorkItemTags.limit).Tostring("P")

    if ($($WorkItemTags.count / $WorkItemTags.limit) -gt 0.9) {
        $resultMarkdown = "Work Item Tags Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    } else {
        $resultMarkdown = "Well done. Work Item Tags Resource Usage limit is at $CurrentUsage"
        $result = $true
    }



    Add-MtTestResultDetail -Result $resultMarkdown -Severity 'High'

    return $result
}
