function Test-AzdoOrganizationCreationClassicBuildPipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PipelineCreation = (Get-ADOPSOrganizationPipelineSettings).disableClassicBuildPipelineCreation

    if ($PipelineCreation) {
        $resultMarkdown = "Well done. No classic build pipelines can be created / imported. Existing ones will continue to work."
        $result = $false
    }
    else {
        $resultMarkdown = "Classic build pipelines can be created / imported."
        $result = $true
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
