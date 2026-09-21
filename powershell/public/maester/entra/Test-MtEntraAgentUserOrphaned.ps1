function Test-MtEntraAgentUserOrphaned {
    <#
    .SYNOPSIS
    Finds Agent Users whose parent Agent Identity is missing.
    .DESCRIPTION
    Checks that each Agent User still has a corresponding Agent Identity. An orphaned Agent User
    is a stale directory account with no clear purpose or lifecycle owner.
    .EXAMPLE
    Test-MtEntraAgentUserOrphaned
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentUserOrphaned
    .LINK
    https://learn.microsoft.com/graph/api/agentuser-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identities and Agent Users.'
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'displayName')
        )
        $AgentUsers = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'users/microsoft.graph.agentUser' `
                -Select @('id', 'displayName', 'userPrincipalName', 'identityParentId')
        )
        Write-Verbose (
            "Found $($AgentIdentities.Count) Agent Identities and " +
            "$($AgentUsers.Count) Agent Users."
        )

        $AgentIdentitiesById = @{}
        foreach ($AgentIdentity in $AgentIdentities) {
            $AgentIdentityId = [string]$AgentIdentity.id
            if (![string]::IsNullOrWhiteSpace($AgentIdentityId)) {
                $AgentIdentitiesById[$AgentIdentityId] = $AgentIdentity
            }
        }

        $OrphanedUsers = @(
            foreach ($AgentUser in $AgentUsers) {
                $ParentIdentityId = [string]$AgentUser.identityParentId
                if ([string]::IsNullOrWhiteSpace($ParentIdentityId)) {
                    [pscustomobject]@{
                        AgentUserId       = [string]$AgentUser.id
                        DisplayName       = [string]$AgentUser.displayName
                        UserPrincipalName = [string]$AgentUser.userPrincipalName
                        ParentIdentityId  = ''
                        Reason            = 'No parent Agent Identity is associated with this user.'
                    }
                    continue
                }

                if (!$AgentIdentitiesById.ContainsKey($ParentIdentityId)) {
                    [pscustomobject]@{
                        AgentUserId       = [string]$AgentUser.id
                        DisplayName       = [string]$AgentUser.displayName
                        UserPrincipalName = [string]$AgentUser.userPrincipalName
                        ParentIdentityId  = $ParentIdentityId
                        Reason            = 'The parent Agent Identity no longer exists.'
                    }
                }
            }
        )

        if ($OrphanedUsers.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No orphaned Agent Users were found. Every Agent User is linked to an ' +
                'existing Agent Identity.'
            )
            return $true
        }

        $Result = "Found $($OrphanedUsers.Count) Agent User object(s) without a matching Agent " +
            'Identity.'
        $Result += ' Review the user and its access before deleting it or restoring its parent ' +
            'identity.'
        $Result += "`n`n| Agent User | Display name | User principal name | " +
            "Parent Agent Identity object ID | Reason |"
        $Result += "`n| --- | --- | --- | --- | --- |"
        foreach ($OrphanedUser in $OrphanedUsers) {
            $DisplayName = [string]$OrphanedUser.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) {
                $DisplayName = '(unnamed)'
            }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $UserPrincipalName = [System.Net.WebUtility]::HtmlEncode(
                [string]$OrphanedUser.UserPrincipalName
            ) -replace '\|', '&#124;'
            $UserPrincipalName = $UserPrincipalName -replace "`r?`n", ' '
            $Reason = [string]$OrphanedUser.Reason -replace '\|', '\|'
            $Result += "`n| $($OrphanedUser.AgentUserId) | $DisplayName | " +
                "$UserPrincipalName | $($OrphanedUser.ParentIdentityId) | $Reason |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'Medium'
        return $false
    } catch {
        $ErrorRecord = $_
    }

    if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
    } else {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
    }
    return $null
}
