function Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTasks {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableMarketplaceTasksVar

    if ($result) {
        $resultMarkdown = "Well done. The ability to install and run tasks from the Marketplace has been restricted."
    }
    else {
        $resultMarkdown = "It is allowed to install and run tasks from the Marketplace."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'Critical'

    return $result
}
