function Test-AzdoOrganizationRepositorySettingsGravatarImages {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationRepositorySettings | Where-object key -eq "GravatarEnabled").value

    if ($result) {
        $resultMarkdown = "Gravatar images are exposed for users outside of your enterprise."
    }
    else {
        $resultMarkdown = "Well done. Gravatar images are not exposed outside of your enterprise."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'Medium'

    return $result
}
