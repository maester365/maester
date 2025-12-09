function Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceJobAuthScopeForReleases

    if ($result) {
        $resultMarkdown = "Well done. Access tokens have reduced scope of access for all classic release pipelines."
    }
    else {
        $resultMarkdown = "Classic Release Pipelines can run with collection scoped access tokens"
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
