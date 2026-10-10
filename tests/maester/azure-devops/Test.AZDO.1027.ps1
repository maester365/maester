function Test-MtCheckAZDO1027 {
    <#
    .SYNOPSIS
    Disable showing Gravatar images for users outside of your enterprise.

    .DESCRIPTION
    Runs the shared check Test-AzdoOrganizationRepositorySettingsGravatarImage.
    #>
    [MaesterTest(
        Id = 'AZDO.1027',
        Title = 'Disable showing Gravatar images for users outside of your enterprise.',
        Severity = 'Medium',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/repos/git/repository-settings?view=azure-devops&tabs=browser#gravatar-images'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-AzdoOrganizationRepositorySettingsGravatarImage
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
