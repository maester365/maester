function Test-AzdoOrganizationStageChooser {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $StageChooser = (Get-ADOPSOrganizationPipelineSettings).disableStageChooser

    if ($result) {
        $resultMarkdown = "Well done. Users will not be able to select stages to skip from the Queue Pipeline panel."
        $result = $false
    }
    else {
        $resultMarkdown = "Users are able to select stages to skip from the Queue Pipeline panel."
        $result = $true
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
