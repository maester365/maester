function Test-MtDynamicGroupMemberOfRule {
    <#
    .SYNOPSIS
    Checks for dynamic groups that use the retiring memberOf rule operator.
    .DESCRIPTION
    Finds user and device dynamic membership rules that use memberOf. Microsoft ends the public
    preview on November 3, 2026, after which affected groups stop updating and retain membership.
    .EXAMPLE
    Test-MtDynamicGroupMemberOfRule
    .LINK
    https://maester.dev/docs/commands/Test-MtDynamicGroupMemberOfRule
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    try {
        $GraphParameters = @{
            RelativeUri     = 'groups'
            Filter          = "groupTypes/any(groupType:groupType eq 'DynamicMembership')"
            Select          = @(
                'id', 'displayName', 'groupTypes', 'membershipRule',
                'membershipRuleProcessingState', 'assignedLicenses'
            )
            QueryParameters = @{ '$count' = 'true' }
        }
        $Groups = @(Invoke-MtGraphRequest @GraphParameters)
        $AffectedGroups = @(
            foreach ($Group in $Groups) {
                $Analysis = @(Get-MtDynamicGroupRuleAnalysis -MembershipRule $Group.membershipRule)
                $MemberOfAnalysis = @($Analysis | Where-Object Category -eq 'MemberOf')
                if ($MemberOfAnalysis.Count -gt 0) {
                    [pscustomobject]@{ Group = $Group; Analysis = $MemberOfAnalysis }
                }
            }
        )
        if ($AffectedGroups.Count -eq 0) {
            $Result = 'Well done. No dynamic groups use the retiring memberOf rule operator.'
            Add-MtTestResultDetail -Result $Result
            return $true
        }
        $SourceGroupIds = @($AffectedGroups.Analysis.ReferencedGroupIds | Select-Object -Unique)
        $SourceGroups = @()
        if ($SourceGroupIds.Count -gt 0) {
            try {
                $SourceGroups = @(
                    Invoke-MtGraphRequest -RelativeUri groups -UniqueId $SourceGroupIds `
                        -Select id, displayName
                )
            } catch {
                Write-Verbose "Unable to resolve memberOf source groups: $($_.Exception.Message)"
            }
        }
        $CaReferences = @(Get-MtDynamicGroupCaReference -GroupId $AffectedGroups.Group.id)
        $RetirementDate = [datetime]'2026-11-03'
        $Today = (Get-Date).ToUniversalTime().Date
        if ($Today -lt $RetirementDate) {
            $DaysRemaining = [int]($RetirementDate - $Today).TotalDays
            $DeadlineText = 'Microsoft retires memberOf on November 3, 2026 ' +
                "($DaysRemaining days remaining)."
        } else {
            $DeadlineText = 'Microsoft retired memberOf on November 3, 2026; ' +
                'membership may already be stale.'
        }
        $Result = "$DeadlineText Found $($AffectedGroups.Count) affected dynamic group(s)."
        $Result += "`n`n| Group | Source groups | Processing | Licenses | CA references | Rule |"
        $Result += "`n| --- | --- | --- | ---: | --- | --- |"
        foreach ($AffectedGroup in $AffectedGroups) {
            $Group = $AffectedGroup.Group
            $GroupLink = Get-GraphObjectMarkdown -GraphObjects $Group `
                -GraphObjectType Groups -AsPlainTextLink
            $Ids = @($AffectedGroup.Analysis.ReferencedGroupIds | Select-Object -Unique)
            $SourceLinks = @($Ids | ForEach-Object {
                    $Id = $_
                    $SourceGroup = $SourceGroups | Where-Object id -eq $Id | Select-Object -First 1
                    if ($SourceGroup) {
                        Get-GraphObjectMarkdown -GraphObjects $SourceGroup `
                            -GraphObjectType Groups -AsPlainTextLink
                    } else {
                        "``$Id`` (unresolved)"
                    }
                }) -join '<br>'
            if (!$SourceLinks) { $SourceLinks = 'None parsed' }
            $CaText = Get-MtDynamicGroupCaReferenceMarkdown `
                -Reference $CaReferences -GroupId $Group.id
            $SingleLineRule = $Group.membershipRule -replace "`r?`n", ' '
            $Rule = [System.Net.WebUtility]::HtmlEncode($SingleLineRule) -replace '\|', '&#124;'
            $Result += "`n| $GroupLink | $SourceLinks | $($Group.membershipRuleProcessingState) | "
            $Result += "$(@($Group.assignedLicenses).Count) | $CaText | <code>$Rule</code> |"
        }
        Add-MtTestResultDetail -Result $Result
        return $false
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
