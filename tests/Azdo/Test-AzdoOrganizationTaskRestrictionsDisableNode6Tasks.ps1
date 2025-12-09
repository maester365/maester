function Test-AzdoOrganizationTaskRestrictionsDisableNode6Tasks {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableNode6TasksVar

    if ($result) {
        $resultMarkdown = "Well done. Pipelines will fail if they utilize a task with a Node 6 execution handler."
    }
    else {
        $resultMarkdown = "Pipeliens may utilize a task with Node 6 execution handler."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'High'

    return $result
}
