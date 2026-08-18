function Test-MtEntraAgentInactive {
    <#
    .SYNOPSIS
    Finds enabled Agent Identities that have not signed in or been active within 180 days.
    .DESCRIPTION
    Checks whether enabled Agent Identities have recent sign-in activity. Stale enabled agents
    retain permissions and token-exchange capabilities without operational oversight, increasing
    the risk of unmonitored persistence or unused privileges.
    .EXAMPLE
    Test-MtEntraAgentInactive
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentInactive
    .LINK
    https://learn.microsoft.com/graph/api/reportroot-list-serviceprincipalsigninactivities?view=graph-rest-beta
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum allowed days of inactivity before flagging an enabled agent. Defaults to 180 days.
        [Parameter(Mandatory = $false)]
        [int]$MaxInactiveDays = 180
    )

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading enabled Agent Identities.'
        $AgentIdentities = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentity' `
                -Select @('id', 'appId', 'displayName', 'accountEnabled', 'createdDateTime')
        )

        $EnabledAgents = @($AgentIdentities | Where-Object { $null -eq $_.accountEnabled -or $_.accountEnabled -eq $true })
        Write-Verbose "Found $($AgentIdentities.Count) Agent Identities ($($EnabledAgents.Count) enabled)."

        if ($EnabledAgents.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No enabled Agent Identities found in the tenant.'
            )
            return $true
        }

        Write-Verbose 'Reading service principal sign-in activities from Graph beta.'
        $SignInActivities = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' `
                -RelativeUri 'reports/servicePrincipalSignInActivities'
        )

        $ActivitiesByAppId = @{}
        foreach ($Activity in $SignInActivities) {
            $AppId = [string]$Activity.appId
            if (![string]::IsNullOrWhiteSpace($AppId)) {
                $ActivitiesByAppId[$AppId] = $Activity
            }
        }

        $InactiveAgents = [System.Collections.Generic.List[pscustomobject]]::new()
        $UtcNow = (Get-Date).ToUniversalTime()

        foreach ($Agent in $EnabledAgents) {
            $AppId = [string]$Agent.appId
            $Activity = if (![string]::IsNullOrWhiteSpace($AppId) -and $ActivitiesByAppId.ContainsKey($AppId)) {
                $ActivitiesByAppId[$AppId]
            } else { $null }

            $LastSignInDate = $null
            if ($null -ne $Activity) {
                $Candidates = [System.Collections.Generic.List[string]]::new()
                if (![string]::IsNullOrWhiteSpace($Activity.lastSignInDateTime)) {
                    $Candidates.Add([string]$Activity.lastSignInDateTime)
                }
                if ($null -ne $Activity.delegatedClientSignInActivity -and ![string]::IsNullOrWhiteSpace($Activity.delegatedClientSignInActivity.lastSignInDateTime)) {
                    $Candidates.Add([string]$Activity.delegatedClientSignInActivity.lastSignInDateTime)
                }
                if ($null -ne $Activity.delegatedResourceSignInActivity -and ![string]::IsNullOrWhiteSpace($Activity.delegatedResourceSignInActivity.lastSignInDateTime)) {
                    $Candidates.Add([string]$Activity.delegatedResourceSignInActivity.lastSignInDateTime)
                }
                if ($null -ne $Activity.applicationAuthenticationClientSignInActivity -and ![string]::IsNullOrWhiteSpace($Activity.applicationAuthenticationClientSignInActivity.lastSignInDateTime)) {
                    $Candidates.Add([string]$Activity.applicationAuthenticationClientSignInActivity.lastSignInDateTime)
                }
                if ($null -ne $Activity.applicationAuthenticationResourceSignInActivity -and ![string]::IsNullOrWhiteSpace($Activity.applicationAuthenticationResourceSignInActivity.lastSignInDateTime)) {
                    $Candidates.Add([string]$Activity.applicationAuthenticationResourceSignInActivity.lastSignInDateTime)
                }

                foreach ($Candidate in $Candidates) {
                    $parsed = [datetime]::MinValue
                    if ([datetime]::TryParse([string]$Candidate, [ref]$parsed)) {
                        $ParsedDate = $parsed.ToUniversalTime()
                        if ($null -eq $LastSignInDate -or $ParsedDate -gt $LastSignInDate) {
                            $LastSignInDate = $ParsedDate
                        }
                    }
                }
            }

            if ($null -ne $LastSignInDate) {
                $DaysSinceSignIn = [int]($UtcNow.Subtract($LastSignInDate).TotalDays)
                if ($DaysSinceSignIn -gt $MaxInactiveDays) {
                    $InactiveAgents.Add([pscustomobject]@{
                        ObjectId       = [string]$Agent.id
                        DisplayName    = [string]$Agent.displayName
                        AppId          = $AppId
                        LastSignIn     = $LastSignInDate.ToString('yyyy-MM-dd')
                        InactiveDays   = $DaysSinceSignIn
                        Reason         = "Inactive for $DaysSinceSignIn days (exceeds $MaxInactiveDays days)."
                    })
                }
            } else {
                # Check creation date if never signed in
                $CreatedDate = $null
                $parsedCreated = [datetime]::MinValue
                if (![string]::IsNullOrWhiteSpace($Agent.createdDateTime) -and [datetime]::TryParse([string]$Agent.createdDateTime, [ref]$parsedCreated)) {
                    $CreatedDate = $parsedCreated.ToUniversalTime()
                }

                $DaysSinceCreation = if ($null -ne $CreatedDate) { [int]($UtcNow.Subtract($CreatedDate).TotalDays) } else { $MaxInactiveDays + 1 }
                if ($DaysSinceCreation -gt $MaxInactiveDays) {
                    $InactiveAgents.Add([pscustomobject]@{
                        ObjectId       = [string]$Agent.id
                        DisplayName    = [string]$Agent.displayName
                        AppId          = $AppId
                        LastSignIn     = 'Never'
                        InactiveDays   = $DaysSinceCreation
                        Reason         = "No recorded sign-in activity since creation ($DaysSinceCreation days ago)."
                    })
                }
            }
        }

        if ($InactiveAgents.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                "Well done. All enabled Agent Identities have active sign-in activity within the last $MaxInactiveDays days."
            )
            return $true
        }

        $Result = "Found $($InactiveAgents.Count) enabled Agent Identity object(s) with no recent sign-in activity in the last $MaxInactiveDays days."
        $Result += "`n`n| Agent Identity object ID | Display name | App ID | Last sign-in | Inactive days | Reason |"
        $Result += "`n| --- | --- | --- | --- | --- | --- |"
        foreach ($Item in $InactiveAgents) {
            $DisplayName = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $Reason = [System.Net.WebUtility]::HtmlEncode([string]$Item.Reason) -replace '\|', '&#124;'
            $Result += "`n| ``$($Item.ObjectId)`` | $DisplayName | ``$($Item.AppId)`` | $($Item.LastSignIn) | $($Item.InactiveDays) | $Reason |"
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
