<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    By default, all administrators can invite new users to their Azure DevOps organization.
    Disabling this policy prevents Team and Project Administrators from inviting new users or adding Entra groups.
    However, Project Collection Administrators (PCAs) can still add new users and Entra groups to the organization regardless of the policy status.
    Additionally, if a user is already a member of the organization, Project and Team Administrators can add that user to specific projects.

    https://aka.ms/azure-devops-invitations-policy

.EXAMPLE
    ```
    Test-AzdoAllowTeamAdminsInvitationsAccessToken
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoAllowTeamAdminsInvitationsAccessToken
#>

function Test-AzdoAllowTeamAdminsInvitationsAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowTeamAdminsInvitationsAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Team and project administrators is allowed to invite new users"
    }
    else {
        $resultMarkdown = "Well done. Enrolling to your Azure DevOps organization should be a controlled process."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
