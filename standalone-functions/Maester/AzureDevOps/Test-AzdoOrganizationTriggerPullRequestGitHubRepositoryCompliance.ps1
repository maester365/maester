function Test-AzdoOrganizationTriggerPullRequestGitHubRepositoryCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status if Azure Pipelines can automatically build and validate every pull request and commit to your GitHub repository.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#validate-contributions-from-forks
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationTriggerPullRequestGitHubRepositoryCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoOrganizationTriggerPullRequestGitHubRepository"


    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        return $null
    }

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
            Prevent pipelines from making secrets available to fork builds is set to '{0}'
            Prevent pipelines from making fork builds have the same permissions as regular builds is set to '{1}'
            Require a team member's comment before building a pull request is set to '{2}' ({3})
'@ -f $settings.enforceNoAccessToSecretsFromForks, $settings.enforceJobAuthScopeForForks, $settings.isCommentRequiredForPullRequest, $AdditionalInfo

        $resultMarkdown = "You have configured building pull requests from forked GitHub repositories according to your requirements. $data"
    } else {
        $resultMarkdown = "No limits building pull requests from forked GitHub repositories have been configured."
    }


    return $result

}
