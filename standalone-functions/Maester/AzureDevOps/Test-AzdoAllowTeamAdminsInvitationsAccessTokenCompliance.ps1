function Test-AzdoAllowTeamAdminsInvitationsAccessTokenCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    By default, all administrators can invite new users to their Azure DevOps organization.
    Disabling this policy prevents Team and Project Administrators from inviting new users or adding Entra groups.
    However, Project Collection Administrators (PCAs) can still add new users and Entra groups to the organization regardless of the policy status.
    Additionally, if a user is already a member of the organization, Project and Team Administrators can add that user to specific projects.

    https://aka.ms/azure-devops-invitations-policy
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoAllowTeamAdminsInvitationsAccessTokenCompliance
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
    Write-Verbose "Running Test-AzdoAllowTeamAdminsInvitationsAccessToken"


    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User' -Force
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowTeamAdminsInvitationsAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Team and project administrators are allowed to invite new users"
    } else {
        $resultMarkdown = "Enrolling to your Azure DevOps organization should be a controlled process."
    }


    return $result

}
