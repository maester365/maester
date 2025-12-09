function Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepos {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationRepositorySettings | Where-object key -eq "DisableTfvcRepositories").value

    if ($result) {
        $resultMarkdown = "Well done. Team Foundation Version Control (TFVC) repositories cannot be created."
    }
    else {
        $resultMarkdown = "Team Foundation Version Control (TFVC) can be created."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
