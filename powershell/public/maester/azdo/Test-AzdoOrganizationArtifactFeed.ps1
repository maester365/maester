function Test-AzdoOrganizationProtectAccessToRepositories {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceReferencedRepoScopedToken

    if ($result) {
        $resultMarkdown = "Well done. Checks and approvals are applied when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline."
    }
    else {
        $resultMarkdown = "Checks and approvals are not applied when accessing repositories from YAML pipelines. Also, a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline is not generated."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result

    ## https://learn.microsoft.com/en-us/azure/devops/artifacts/feeds/feed-permissions?view=azure-devops&tabs=nuget%2Cnugetserver22%2Cnugetserver
}
