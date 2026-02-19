<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if Azure Pipelines can automatically build and validate every pull request and commit to your GitHub repository.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#validate-contributions-from-forks

.EXAMPLE
    ```
    Test-AzdoOrganizationTriggerPullRequestGitHubRepository
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationTriggerPullRequestGitHubRepository
#>
function Test-AzdoOrganizationTriggerPullRequestGitHubRepository {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
        break
    }

    $settings = Get-ADOPSOrganizationPipelineSettings
    $result = $settings.forkProtectionEnabled

    if ($result) {
        if ($settings.requireCommentsForNonTeamMemberAndNonContributors) {
            $AdditionalInfo = 'Only on pull requests from non-team members and contributors'
        } elseif ($settings.requireCommentsForNonTeamMembersOnly) {
            $AdditionalInfo = 'Only on pull requests from non-team members'
        } else {
            $AdditionalInfo = 'On all pull requests'
        }

        $data = @'
            Prevent pipelines from making secrets available to fork builds is set to '{0}'\
            Prevent pipelines from making fork builds have the same permissions as regular builds is set to '{1}'\
            Require a team member's comment before building a pull request is set to '{2}' ({3})
'@ -f $settings.enforceNoAccessToSecretsFromForks, $settings.enforceJobAuthScopeForForks, $settings.isCommentRequiredForPullRequest, $AdditionalInfo

        $resultMarkdown = "Well done. You have configured building pull requests from forked GitHub repositories according to your requirements. $data"
    } else {
        $resultMarkdown = "No limits building pull requests from forked GitHub repositories have been configured."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
