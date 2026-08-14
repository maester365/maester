function Test-MtDynamicGroupUserControlledAttributes {
    <#
    .SYNOPSIS
    Identifies dynamic group rules that use attributes whose writers should be reviewed.

    .DESCRIPTION
    Finds dynamic user group rules that reference user-influenceable profile properties or
    lower-risk identity and extension attributes normally controlled by privileged writers.
    Results are separated by risk and marked Investigate because rule text alone does not prove
    who can change the property or what access the group grants.

    .EXAMPLE
    Test-MtDynamicGroupUserControlledAttributes

    Returns true and marks candidate rules for investigation.

    .LINK
    https://maester.dev/docs/commands/Test-MtDynamicGroupUserControlledAttributes
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '', Justification = 'The check evaluates multiple attributes.')]
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
        Write-Verbose "Retrieved $($Groups.Count) dynamic group(s) for attribute rule analysis."
        $Candidates = @(
            foreach ($Group in $Groups) {
                $RuleAnalysis = Get-MtDynamicGroupRuleAnalysis -MembershipRule $Group.membershipRule
                foreach ($Analysis in $RuleAnalysis) {
                    if ($Analysis.Category -in @(
                            'RiskyUserInfluenceable', 'LowRiskPrivilegedControlled')) {
                        [pscustomobject]@{ Group = $Group; Analysis = $Analysis }
                    }
                }
            }
        )

        if ($Candidates.Count -eq 0) {
            $Result = 'Well done. No dynamic group rules use attributes that require a review ' +
                'of who can change them.'
            Add-MtTestResultDetail -Result $Result
            return $true
        }

        $GroupIds = @($Candidates.Group.id | Select-Object -Unique)
        $CaReferences = @(Get-MtDynamicGroupCaReference -GroupId $GroupIds)
        $Result = "Found $($GroupIds.Count) dynamic group(s) whose rules require review. " +
            'A match is not proof of exploitability; validate who can change each attribute ' +
            'and what access the group grants.'

        $RiskSections = @(
            [pscustomobject]@{
                Category    = 'RiskyUserInfluenceable'
                Heading     = 'Risky - user-influenceable attributes'
                Description = 'These profile or employment attributes may be influenced directly ' +
                    'or through HR, onboarding, profile, or support workflows.'
                ReviewFocus = 'Verify every direct and indirect path available to the user'
            }
            [pscustomobject]@{
                Category    = 'LowRiskPrivilegedControlled'
                Heading     = 'Low risk - application or administrator-controlled attributes'
                Description = 'These identity and extension attributes are normally written by ' +
                    'privileged applications, administrators, Exchange, or synchronization services.'
                ReviewFocus = 'Verify the privileged applications, administrators, and source systems'
            }
        )

        foreach ($RiskSection in $RiskSections) {
            $RiskCandidates = @(
                $Candidates | Where-Object {
                    $_.Analysis.Category -eq $RiskSection.Category
                }
            )
            if ($RiskCandidates.Count -eq 0) {
                continue
            }

            $RiskGroupCount = @($RiskCandidates.Group.id | Select-Object -Unique).Count
            $Result += "`n`n#### $($RiskSection.Heading)"
            $Result += "`n`n$($RiskSection.Description) Found $RiskGroupCount group(s)."
            $Result += "`n`n| Group | Property | Operator | Review focus | Processing | " +
                'Licenses | Conditional Access policies | Rule |'
            $Result += "`n| --- | --- | --- | --- | --- | ---: | --- | --- |"

            foreach ($Candidate in $RiskCandidates) {
                $Group = $Candidate.Group
                $Analysis = $Candidate.Analysis
                $GroupLink = Get-GraphObjectMarkdown -GraphObjects $Group `
                    -GraphObjectType Groups -AsPlainTextLink
                $ReviewFocus = $RiskSection.ReviewFocus
                if ($Analysis.UsesPatternMatch) {
                    $ReviewFocus += '; pattern or partial matching broadens the rule'
                }
                $CaText = Get-MtDynamicGroupCaReferenceMarkdown `
                    -Reference $CaReferences -GroupId $Group.id
                $SingleLineRule = $Group.membershipRule -replace "`r?`n", ' '
                $Rule = [System.Net.WebUtility]::HtmlEncode($SingleLineRule) -replace '\|', '&#124;'
                $LicenceCount = @($Group.assignedLicenses).Count
                $Result += "`n| $GroupLink | ``$($Analysis.ObjectType).$($Analysis.Property)`` | "
                $ProcessingState = $Group.membershipRuleProcessingState
                $Result += "``$($Analysis.Operator)`` | $ReviewFocus | $ProcessingState | "
                $Result += "$LicenceCount | $CaText | <code>$Rule</code> |"
            }
        }

        Add-MtTestResultDetail -Result $Result -Investigate
        return $true
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
