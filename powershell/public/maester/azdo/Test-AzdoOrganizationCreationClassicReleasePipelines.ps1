function Test-AzdoOrganizationCreationClassicReleasePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PipelineCreation = (Get-ADOPSOrganizationPipelineSettings).disableClassicReleasePipelineCreation

    if ($PipelineCreation) {
        $resultMarkdown = "Well done. No classic release pipelines, task groups, and deployment groups can be created / imported. Existing ones will continue to work."
        $result = $false
    }
    else {
        $resultMarkdown = "Classic release pipelines, task groups, and deployment groups can be created / imported."
        $result = $true
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
