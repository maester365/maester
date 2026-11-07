function Get-MtAzureSecureScoreInstance {
    <#
    .SYNOPSIS
    Returns one MT.1266 instance per Azure subscription Microsoft Defender for Cloud scores.

    .DESCRIPTION
    Instance source of the MT.1266 family. The suffix is the subscription ID (MT.1266.<subscriptionId>)
    and the title names the subscription, so each subscription carries its own result and its own
    history.

    Every subscription Defender for Cloud scored is emitted, including one whose maximum score is zero.
    That subscription is skipped by the test with a reason rather than dropped here: a subscription the
    user knows exists should not vanish from the report.

    When Defender for Cloud returns no score at all the source emits nothing and the engine skips the
    family with NoInstances. A tenant with no scored subscription has no score to meet, and must never
    be reported as meeting it.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    foreach ($subscription in Get-MtAzureSecureScore) {
        [pscustomobject]@{
            Id    = $subscription.SubscriptionId
            Title = "The Defender for Cloud secure score of subscription '$($subscription.SubscriptionName)' should meet the target."
            Data  = $subscription
        }
    }
}

function Test-MtAzureSecureScore {
    <#
    .SYNOPSIS
    Checks that an Azure subscription meets the Microsoft Defender for Cloud secure score target.

    .DESCRIPTION
    Defender for Cloud scores every subscription it covers against its recommendations and expresses the
    result as a percentage of the maximum achievable score. An assessor reads that number first and the
    individual recommendations afterwards. This check brings the number into a Maester run, one result
    per subscription, and carries the state of the regulatory compliance standards assigned to that
    subscription in the same result.

    A subscription passes when its secure score reaches MinimumScorePercentage and fails below it. The
    target is a business decision rather than a vendor rule, so it is a parameter: 80 by default, and a
    TestSettings row in the config can set another value per subscription instance.

    The regulatory compliance standards are reported as a summary table, not as separate results. Each
    standard's controls are already covered by the Defender for Cloud recommendation check (MT.1257),
    and reporting them twice would double count the same finding.

    .PARAMETER MinimumScorePercentage
    The secure score percentage a subscription must reach to pass. 80 by default.

    .PARAMETER Instance
    The subscription to check, supplied by the engine.

    .OUTPUTS
    [bool] - True when the subscription reaches the target, false when it does not, null when skipped.

    .EXAMPLE
    Test-MtAzureSecureScore

    Returns one result per scored Azure subscription.

    .LINK
    https://maester.dev/docs/commands/Test-MtAzureSecureScore
    #>
    [MaesterTest(
        Id = 'MT.1266',
        Title = 'Azure subscriptions should meet the Microsoft Defender for Cloud secure score target.',
        Product = 'azure',
        RelatedProduct = 'defender',
        Feature = 'subscriptions',
        Area = 'infrastructure',
        ResourceType = 'AzureResource',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Lifecycle = 'Preview',
        Service = 'Azure',
        Permission = 'Azure:Role:Reader | Azure:Role:Security Reader',
        InstanceSource = 'Get-MtAzureSecureScoreInstance',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The secure score percentage a subscription must reach to pass.
        [ValidateRange(0, 100)]
        [int] $MinimumScorePercentage = 80,

        # The subscription to check, supplied by the engine.
        $Instance
    )

    $subscription = $Instance.Data
    $name = Get-MtSafeMarkdown ([string]$subscription.SubscriptionName)

    if ($null -eq $subscription.ScorePercentage) {
        # Defender for Cloud produced a score row with a maximum of zero, so it assessed nothing in this
        # subscription. No score is not a score of zero, and it is certainly not a pass.
        # $name, not the raw SubscriptionName: the reason is rendered as markdown like any other result
        # text, and a subscription name is tenant-controlled.
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Defender for Cloud assessed nothing in subscription '$name': its maximum secure score is zero, so there is no percentage to compare."
        return $null
    }

    $percentage = [double]$subscription.ScorePercentage
    $testResult = $percentage -ge $MinimumScorePercentage

    $testResultMarkdown = "The Defender for Cloud secure score of **$name** is **$percentage%**, against a target of **$MinimumScorePercentage%**.`n`n"
    $testResultMarkdown += "| Property | Value |`n| --- | --- |`n"
    $testResultMarkdown += "| Subscription | $name |`n"
    $testResultMarkdown += "| Subscription ID | ``$($subscription.SubscriptionId)`` |`n"
    $testResultMarkdown += "| Secure score | $($subscription.CurrentScore) of $($subscription.MaxScore) points |`n"
    $testResultMarkdown += "| Percentage | $percentage% |`n"
    $testResultMarkdown += "| Target | $MinimumScorePercentage% |`n"

    $standards = @($subscription.StandardList | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace($_.Standard) })
    if ($standards.Count -gt 0) {
        $testResultMarkdown += "`n**Regulatory compliance standards assigned to this subscription.** Reported as a summary: the controls behind these numbers are covered by MT.1257, and repeating them here would count the same finding twice.`n`n"
        $testResultMarkdown += "| Standard | State | Passed | Failed | Skipped | Unsupported |`n| --- | --- | --- | --- | --- | --- |`n"
        foreach ($standard in ($standards | Sort-Object -Property @{ Expression = { [int]$_.FailedControls } ; Descending = $true }, Standard)) {
            $standardName = Get-MtSafeMarkdown ([string]$standard.Standard)
            $state = Get-MtSafeMarkdown ([string]$standard.State)
            $testResultMarkdown += "| $standardName | $state | $($standard.PassedControls) | $($standard.FailedControls) | $($standard.SkippedControls) | $($standard.UnsupportedControls) |`n"
        }
    } else {
        $testResultMarkdown += "`nNo regulatory compliance standard is assigned to this subscription. The Microsoft cloud security benchmark is assigned by default, so an empty list usually means it was removed.`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. This subscription is at or above the secure score target."
    } else {
        $testResultMarkdown += "`nRaise the score in **Microsoft Defender for Cloud** → **Secure score**, which lists the controls by how many points each would add. The points are weighted, so the controls at the top of that list move the number furthest."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
