function Test-MtEntraAgentInactive {
    <#
    .SYNOPSIS
    Finds enabled Agent Identities that have not signed in or been active within 180 days.
    .DESCRIPTION
    Checks whether enabled Agent Identities have recent sign-in activity, and separately flags a
    Blueprint whose entire fleet of child Agent Identities is inactive while the Blueprint still
    holds a live (non-expired) credential. Stale enabled agents retain permissions and
    token-exchange capabilities without operational oversight, increasing the risk of unmonitored
    persistence or unused privileges; a fully dormant fleet with a live parent credential is a
    stronger signal that the Blueprint itself is a cleanup candidate.
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
                -Select @('id', 'appId', 'displayName', 'accountEnabled', 'createdDateTime', 'agentIdentityBlueprintId')
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

            # Graph-typed date/time properties already arrive as native [datetime] objects.
            # Casting through [string] first forces a culture-formatted render (e.g. day-first
            # locales), which then fails or silently misparses when re-parsed -- cast directly
            # instead, matching the pattern used by Test-MtAIAgentDormant.ps1.
            $LastSignInDate = $null
            if ($null -ne $Activity) {
                $Candidates = [System.Collections.Generic.List[object]]::new()
                if ($Activity.lastSignInDateTime) { $Candidates.Add($Activity.lastSignInDateTime) }
                if ($Activity.delegatedClientSignInActivity -and $Activity.delegatedClientSignInActivity.lastSignInDateTime) {
                    $Candidates.Add($Activity.delegatedClientSignInActivity.lastSignInDateTime)
                }
                if ($Activity.delegatedResourceSignInActivity -and $Activity.delegatedResourceSignInActivity.lastSignInDateTime) {
                    $Candidates.Add($Activity.delegatedResourceSignInActivity.lastSignInDateTime)
                }
                if ($Activity.applicationAuthenticationClientSignInActivity -and $Activity.applicationAuthenticationClientSignInActivity.lastSignInDateTime) {
                    $Candidates.Add($Activity.applicationAuthenticationClientSignInActivity.lastSignInDateTime)
                }
                if ($Activity.applicationAuthenticationResourceSignInActivity -and $Activity.applicationAuthenticationResourceSignInActivity.lastSignInDateTime) {
                    $Candidates.Add($Activity.applicationAuthenticationResourceSignInActivity.lastSignInDateTime)
                }

                foreach ($Candidate in $Candidates) {
                    $ParsedDate = $Candidate -as [datetime]
                    if ($null -ne $ParsedDate) {
                        $ParsedDate = $ParsedDate.ToUniversalTime()
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
                $CreatedDate = $Agent.createdDateTime -as [datetime]
                if ($null -ne $CreatedDate) {
                    $CreatedDate = $CreatedDate.ToUniversalTime()
                }

                $DaysSinceCreation = if ($null -ne $CreatedDate) {
                    [int]($UtcNow.Subtract($CreatedDate).TotalDays)
                } else {
                    $null
                }
                if ($null -eq $DaysSinceCreation -or $DaysSinceCreation -gt $MaxInactiveDays) {
                    if ($null -eq $DaysSinceCreation) {
                        $InactiveDays = 'Unknown'
                        $InactivityReason = (
                            'No recorded sign-in activity, and the creation date could not be ' +
                            'determined.'
                        )
                    } else {
                        $InactiveDays = $DaysSinceCreation
                        $InactivityReason = (
                            "No recorded sign-in activity since creation " +
                            "($DaysSinceCreation days ago)."
                        )
                    }
                    $InactiveAgents.Add([pscustomobject]@{
                        ObjectId       = [string]$Agent.id
                        DisplayName    = [string]$Agent.displayName
                        AppId          = $AppId
                        LastSignIn     = 'Never'
                        InactiveDays   = $InactiveDays
                        Reason         = $InactivityReason
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

        # Compound signal: every agent under a Blueprint is individually inactive AND the
        # Blueprint still holds a live (non-expired) credential -- a fully dormant fleet with a
        # live parent credential is a stronger cleanup candidate than any single stale agent.
        $DormantFleetFindings = [System.Collections.Generic.List[pscustomobject]]::new()
        $InactiveAgentIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($InactiveAgents.ObjectId))
        $AgentsByBlueprintAppId = @{}
        foreach ($Agent in $EnabledAgents) {
            $ParentAppId = [string]$Agent.agentIdentityBlueprintId
            if ([string]::IsNullOrWhiteSpace($ParentAppId)) { continue }
            if (!$AgentsByBlueprintAppId.ContainsKey($ParentAppId)) {
                $AgentsByBlueprintAppId[$ParentAppId] = [System.Collections.Generic.List[object]]::new()
            }
            $AgentsByBlueprintAppId[$ParentAppId].Add($Agent)
        }

        $DormantBlueprintAppIds = @($AgentsByBlueprintAppId.Keys | Where-Object {
            $Group = $AgentsByBlueprintAppId[$_]
            $Group.Count -gt 0 -and (@($Group | Where-Object { !$InactiveAgentIds.Contains([string]$_.id) }).Count -eq 0)
        })

        if ($DormantBlueprintAppIds.Count -gt 0) {
            Write-Verbose 'Reading Agent Identity Blueprints to check for a live credential on fully dormant fleets.'
            $Blueprints = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                    -Select @('id', 'displayName', 'appId', 'passwordCredentials', 'keyCredentials')
            )

            foreach ($Blueprint in $Blueprints) {
                $BlueprintAppId = [string]$Blueprint.appId
                if ($DormantBlueprintAppIds -notcontains $BlueprintAppId) { continue }

                # @($null) yields a one-element array, not an empty one, so a null
                # passwordCredentials/keyCredentials property must be filtered out explicitly
                # before it's mistaken for a credential with no expiry (i.e. "live").
                $AllCredentials = @(@($Blueprint.passwordCredentials) + @($Blueprint.keyCredentials) | Where-Object { $null -ne $_ })
                $LiveCredentials = @($AllCredentials | Where-Object {
                    $ParsedEnd = $_.endDateTime -as [datetime]
                    $null -eq $ParsedEnd -or $ParsedEnd.ToUniversalTime() -ge $UtcNow
                })
                if ($LiveCredentials.Count -eq 0) { continue }

                $Group = $AgentsByBlueprintAppId[$BlueprintAppId]
                $DormantFleetFindings.Add([pscustomobject]@{
                    BlueprintId = [string]$Blueprint.id
                    DisplayName = [string]$Blueprint.displayName
                    AppId       = $BlueprintAppId
                    AgentCount  = $Group.Count
                    Reason      = "All $($Group.Count) child Agent Identit$(if ($Group.Count -eq 1) { 'y is' } else { 'ies are' }) inactive beyond $MaxInactiveDays days, and the Blueprint still holds a live credential."
                })
            }
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
            $Result += "`n| $($Item.ObjectId) | $DisplayName | $($Item.AppId) | " +
                "$($Item.LastSignIn) | $($Item.InactiveDays) | $Reason |"
        }

        if ($DormantFleetFindings.Count -gt 0) {
            $Result += "`n`n$($DormantFleetFindings.Count) Blueprint(s) have a fully dormant fleet while still holding a live credential."
            $Result += "`n`n| Blueprint object ID | Display name | App ID | Agent count | Reason |"
            $Result += "`n| --- | --- | --- | --- | --- |"
            foreach ($Item in $DormantFleetFindings) {
                $Name = [string]$Item.DisplayName
                if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
                $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
                $Name = $Name -replace "`r?`n", ' '
                $Reason = [System.Net.WebUtility]::HtmlEncode([string]$Item.Reason) -replace '\|', '&#124;'
                $Result += "`n| $($Item.BlueprintId) | $Name | $($Item.AppId) | " +
                    "$($Item.AgentCount) | $Reason |"
            }
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
