function Test-AzdoOrganizationBadgesArePrivate {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).statusBadgesArePrivate

    if ($result) {
        $resultMarkdown = "Well done. Azure DevOps badges are private."
    }
    else {
        $resultMarkdown = "Anonymous users can access the status badge API for all pipelines."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
