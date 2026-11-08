function Test-MtDynamicGroupProcessingFailure {
    <#
    .SYNOPSIS
    Checks for dynamic groups whose membership rule processing has failed.

    .DESCRIPTION
    Reads the processing status of every dynamic group whose processing is turned on and reports the
    groups whose status is Failed. Until the error is fixed, the membership of such a group does not
    follow its rule. Microsoft Graph returns the status only when a group is read on its own, from the
    beta endpoint, so the check lists the dynamic groups first and then reads each group that is not
    paused. Paused groups have no processing status and are not evaluated.

    .EXAMPLE
    Test-MtDynamicGroupProcessingFailure

    Returns false and lists each dynamic group whose rule processing failed.

    .LINK
    https://maester.dev/docs/commands/Test-MtDynamicGroupProcessingFailure
    #>
    [MaesterTest(
        Id = 'MT.1265',
        Title = 'Fix dynamic groups whose rule processing failed.',
        Product = 'entra',
        Feature = 'groups',
        Area = 'identity-lifecycle',
        ResourceType = 'Group',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Service = 'Graph',
        Author = 'julien-ly'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $GraphParameters = @{
        RelativeUri     = 'groups'
        Filter          = "groupTypes/any(groupType:groupType eq 'DynamicMembership')"
        Select          = @('id', 'displayName', 'membershipRule', 'membershipRuleProcessingState')
        QueryParameters = @{ '$count' = 'true' }
    }
    $Groups = @(Invoke-MtGraphRequest @GraphParameters)
    if ($Groups.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $ActiveGroups = @($Groups | Where-Object { $_.membershipRuleProcessingState -eq 'On' })
    $PausedCount = $Groups.Count - $ActiveGroups.Count
    $PausedText = ''
    if ($PausedCount -gt 0) {
        $PausedText = "`n`n$PausedCount paused dynamic group(s) were not evaluated. A paused group " +
            'does not update its membership either.'
    }
    if ($ActiveGroups.Count -eq 0) {
        $Reason = 'Processing is paused for every dynamic group, so no group has a processing status ' +
            'to read.'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Reason
        return $null
    }

    # The status is returned only by the Get group API, so each active group is read on its own.
    $StatusParameters = @{
        RelativeUri = 'groups'
        UniqueId    = @($ActiveGroups.id)
        Select      = @('id', 'membershipRuleProcessingStatus')
        ApiVersion  = 'beta'
    }
    $Statuses = @(Invoke-MtGraphRequest @StatusParameters)
    $FailedStatuses = @(
        $Statuses | Where-Object { $_.membershipRuleProcessingStatus.status -eq 'Failed' }
    )

    if ($FailedStatuses.Count -eq 0) {
        $Result = "Well done. None of the $($ActiveGroups.Count) dynamic group(s) with processing " +
            "turned on has a failed rule processing status.$PausedText"
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    # The Conditional Access references only add context. When the policies can't be read, for example
    # because the connection lacks the permission to read them, the failed groups are still reported.
    $CaReferences = @()
    $CaReadError = $null
    try {
        $CaReferences = @(Get-MtDynamicGroupCaReference -GroupId @($FailedStatuses.id))
    } catch {
        $CaReadError = $_
        Write-Verbose "Unable to read the Conditional Access policies: $($_.Exception.Message)"
    }
    $Result = "Found $($FailedStatuses.Count) dynamic group(s) whose rule processing failed. Until " +
        'the error is fixed, their membership does not follow their rule.'
    $Result += "`n`n| Group | Error | CA references | Rule |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Status in $FailedStatuses) {
        $Group = $ActiveGroups | Where-Object id -eq $Status.id | Select-Object -First 1
        $GroupLink = Get-GraphObjectMarkdown -GraphObjects $Group `
            -GraphObjectType Groups -AsPlainTextLink
        $ErrorMessage = [string] $Status.membershipRuleProcessingStatus.errorMessage
        $ErrorText = 'None returned'
        if ($ErrorMessage) {
            $ErrorText = [System.Net.WebUtility]::HtmlEncode($ErrorMessage) -replace '\|', '&#124;'
        }
        $CaText = 'Not available'
        if (-not $CaReadError) {
            $CaText = Get-MtDynamicGroupCaReferenceMarkdown `
                -Reference $CaReferences -GroupId $Group.id
        }
        $SingleLineRule = $Group.membershipRule -replace "`r?`n", ' '
        $Rule = [System.Net.WebUtility]::HtmlEncode($SingleLineRule) -replace '\|', '&#124;'
        $Result += "`n| $GroupLink | $ErrorText | $CaText | <code>$Rule</code> |"
    }
    if ($CaReadError) {
        $CaMessage = $CaReadError.Exception.Message -replace "`r?`n", ' '
        $Result += "`n`nThe Conditional Access policies could not be read, so the CA references are not " +
            "shown: $([System.Net.WebUtility]::HtmlEncode($CaMessage))"
    }
    $Result += $PausedText
    Add-MtTestResultDetail -Result $Result
    return $false
}
