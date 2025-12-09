function Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceJobAuthScope

    if ($result) {
        $resultMarkdown = "Well done. Access tokens have reduced scope of access for all non-release pipelines."
    }
    else {
        $resultMarkdown = "Non-Release Pipelines can run with collection scoped access tokens"
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
