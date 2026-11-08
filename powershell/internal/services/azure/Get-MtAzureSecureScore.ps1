function Get-MtAzureSecureScore {
    <#
    .SYNOPSIS
    Returns one row per Azure subscription with the Microsoft Defender for Cloud secure score and the
    state of the regulatory compliance standards assigned to it.

    .DESCRIPTION
    Runs three Azure Resource Graph queries over the subscriptions the signed-in account can read: the
    secure score per subscription, the regulatory compliance standards per subscription, and the
    subscription names from ResourceContainers so the result names a subscription instead of only its
    GUID.

    The percentage is computed from the current and maximum score rather than read from
    properties.score.percentage, whose unit the Azure samples present two different ways: the secure
    score page divides current by max itself while the Resource Graph sample projects the property
    directly. Dividing here removes the ambiguity.

    A subscription with a maximum score of zero is still returned. Defender for Cloud produced a score
    row for it but assessed nothing, and the caller must say so rather than drop the subscription
    silently or read it as a pass.

    An empty secure score result means Defender for Cloud produced no score for these subscriptions.
    The caller must skip in that case.

    Errors are deliberately not caught here, so a failed query surfaces instead of being read as an
    estate with no score.

    .EXAMPLE
    Get-MtAzureSecureScore

    Returns the secure score and compliance standards of each readable subscription.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    # The name filter is not cosmetic. Score resources are per initiative, and the instance ID for
    # this family is the subscription ID, so a second initiative in one subscription would produce a
    # repeated instance ID. Invoke-MtNativePlan returns a single InvalidInstanceId Error row for the
    # whole family in that case and evaluates nothing, so one extra initiative anywhere in the estate
    # would take MT.1266 out everywhere. 'ascScore' is the ASC Default initiative, per the Azure API.
    # properties.score.max is cast because the score arrives as a dynamic value.
    $scoreQuery = @'
securityresources
| where type == "microsoft.security/securescores"
| where name == "ascScore"
| extend currentScore = todouble(properties.score.current),
         maxScore = todouble(properties.score.max),
         initiative = tostring(properties.displayName)
| project subscriptionId, currentScore, maxScore, initiative
| sort by subscriptionId asc
'@

    # The standards level already carries the control counts this needs, so there is no reason to read
    # the control level and aggregate it back up.
    $standardQuery = @'
securityresources
| where type == "microsoft.security/regulatorycompliancestandards"
| extend standard = name,
         state = tostring(properties.state),
         passedControls = toint(properties.passedControls),
         failedControls = toint(properties.failedControls),
         skippedControls = toint(properties.skippedControls),
         unsupportedControls = toint(properties.unsupportedControls)
| project subscriptionId, standard, state, passedControls, failedControls, skippedControls, unsupportedControls
| sort by subscriptionId asc, standard asc
'@

    $nameQuery = @'
resourcecontainers
| where type == "microsoft.resources/subscriptions"
| project subscriptionId, subscriptionName = name
'@

    Write-Verbose 'Querying the Defender for Cloud secure score through Azure Resource Graph...'
    $scoreRows = @(Invoke-MtAzureResourceGraphRequest -Query $scoreQuery)

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    if ($scoreRows.Count -eq 0) {
        # -NoEnumerate keeps an empty list from collapsing to $null.
        Write-Output $result -NoEnumerate
        return
    }

    Write-Verbose 'Querying the regulatory compliance standards...'
    $standardRows = @(Invoke-MtAzureResourceGraphRequest -Query $standardQuery)
    Write-Verbose 'Querying the subscription names...'
    $nameRows = @(Invoke-MtAzureResourceGraphRequest -Query $nameQuery)

    $nameLookup = @{}
    foreach ($row in $nameRows) {
        if (-not $row -or [string]::IsNullOrWhiteSpace([string]$row.subscriptionId)) { continue }
        $nameLookup[[string]$row.subscriptionId] = [string]$row.subscriptionName
    }

    $standardLookup = @{}
    foreach ($row in $standardRows) {
        if (-not $row -or [string]::IsNullOrWhiteSpace([string]$row.subscriptionId)) { continue }
        $id = [string]$row.subscriptionId
        if (-not $standardLookup.ContainsKey($id)) {
            $standardLookup[$id] = [System.Collections.Generic.List[pscustomobject]]::new()
        }
        $standardLookup[$id].Add([pscustomobject]@{
                Standard            = [string]$row.standard
                State               = [string]$row.state
                PassedControls      = [int]($row.passedControls)
                FailedControls      = [int]($row.failedControls)
                SkippedControls     = [int]($row.skippedControls)
                UnsupportedControls = [int]($row.unsupportedControls)
            })
    }

    foreach ($row in $scoreRows) {
        if (-not $row -or [string]::IsNullOrWhiteSpace([string]$row.subscriptionId)) { continue }
        $id = [string]$row.subscriptionId
        $current = [double]($row.currentScore)
        $max = [double]($row.maxScore)
        # A maximum of zero means nothing was assessed. Reporting 0% there would read as a bad score
        # rather than as no score, so the percentage stays null and the caller skips the subscription.
        # Not rounded: the caller compares it with the target, and 79.96 rounded to 80.0 would pass a target
        # of 80. Round only for display. Decimal, not double: in double 57 of 100 is 56.99999999999999 and would
        # miss a target of 57.
        $percentage = if ($max -gt 0) { [double]([decimal]$current * 100 / [decimal]$max) } else { $null }

        $result.Add([pscustomobject]@{
                SubscriptionId   = $id
                SubscriptionName = if ($nameLookup.ContainsKey($id)) { $nameLookup[$id] } else { $id }
                Initiative       = [string]$row.initiative
                CurrentScore     = $current
                MaxScore         = $max
                ScorePercentage  = $percentage
                StandardList     = if ($standardLookup.ContainsKey($id)) { @($standardLookup[$id]) } else { @() }
            })
    }

    Write-Output $result -NoEnumerate
}
