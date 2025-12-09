function Test-AzdoOrganizationTriggerPullRequestGitHubRepositories {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings
    $result = $settings.forkProtectionEnabled

    if ($result) {
        if ($settings.requireCommentsForNonTeamMemberAndNonContributors) {
            $AdditionalInfo = 'Only on pull requests from non-team members and contributors'
        }
        elseif ($settings.requireCommentsForNonTeamMembersOnly) {
            $AdditionalInfo = 'Only on pull requests from non-team members'
        }
        else {
            $AdditionalInfo = 'On all pull requests'
        }
        
        $data = @'
            Prevent pipelines from making secrets available to fork builds is set to '{0}'\
            Prevent pipelines from making fork builds have the same permissions as regular builds is set to '{1}'\
            Require a team member's comment before building a pull request is set to '{2}' ({3})
'@ -f $settings.enforceNoAccessToSecretsFromForks, $settings.enforceJobAuthScopeForForks, $settings.isCommentRequiredForPullRequest, $AdditionalInfo

        $resultMarkdown = "Well done. You have configured building pull requests from forked GitHub repositories according to your requirements. $data"
    }
    else {
        $resultMarkdown = "No limits building pull requests from forked GitHub repositories have been configured."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown   -Severity 'High'

    return $result
}
