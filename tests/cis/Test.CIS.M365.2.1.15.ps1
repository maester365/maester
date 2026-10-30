function Test-MtCisOutboundSpamLimit {
    <#
    .SYNOPSIS
        Checks that the default outbound spam policy sets recipient limits and blocks the user when they are reached.

    .DESCRIPTION
        Checks the default outbound spam filter policy for recipient limits, the action when a limit is reached, and an outbound spam notification recipient.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.15, L1)

    .EXAMPLE
        Test-MtCisOutboundSpamLimit

        Returns true if the default outbound spam policy has limits and blocks the user when they are exceeded.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.1.15
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.15',
        Title = 'Ensure outbound anti-spam message limits are in place (Default policy only)',
        Product = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1534',
        Control = ('cis-m365:2.1.15', 'nist-800-53-r5:AC-4'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum external recipients per hour.
        [ValidateRange(1, 10000)]
        [int] $MaximumExternalRecipientsPerHour = 500,
        # Maximum internal recipients per hour.
        [ValidateRange(1, 10000)]
        [int] $MaximumInternalRecipientsPerHour = 1000,
        # Maximum recipients per day.
        [ValidateRange(1, 10000)]
        [int] $MaximumRecipientsPerDay = 1000
    )

    $policies = @(Get-MtExo -Request HostedOutboundSpamFilterPolicy)
    $defaultPolicies = @($policies | Where-Object { $_.IsDefault -eq $true })
    $hasDefault = $defaultPolicies.Count -eq 1

    $checks = foreach ($policy in $defaultPolicies) {
        [pscustomobject]@{ Policy = $policy.Name; Setting = 'RecipientLimitExternalPerHour'; Value = $(if ($null -eq ($policy.RecipientLimitExternalPerHour)) { 'Not found' } else { $policy.RecipientLimitExternalPerHour }); Pass = [bool]($policy.RecipientLimitExternalPerHour -gt 0 -and $policy.RecipientLimitExternalPerHour -le $MaximumExternalRecipientsPerHour) }
        [pscustomobject]@{ Policy = $policy.Name; Setting = 'RecipientLimitInternalPerHour'; Value = $(if ($null -eq ($policy.RecipientLimitInternalPerHour)) { 'Not found' } else { $policy.RecipientLimitInternalPerHour }); Pass = [bool]($policy.RecipientLimitInternalPerHour -gt 0 -and $policy.RecipientLimitInternalPerHour -le $MaximumInternalRecipientsPerHour) }
        [pscustomobject]@{ Policy = $policy.Name; Setting = 'RecipientLimitPerDay'; Value = $(if ($null -eq ($policy.RecipientLimitPerDay)) { 'Not found' } else { $policy.RecipientLimitPerDay }); Pass = [bool]($policy.RecipientLimitPerDay -gt 0 -and $policy.RecipientLimitPerDay -le $MaximumRecipientsPerDay) }
        [pscustomobject]@{ Policy = $policy.Name; Setting = 'ActionWhenThresholdReached'; Value = $(if ($null -eq ($policy.ActionWhenThresholdReached)) { 'Not found' } else { $policy.ActionWhenThresholdReached }); Pass = [bool]($policy.ActionWhenThresholdReached -eq 'BlockUser') }
        [pscustomobject]@{ Policy = $policy.Name; Setting = 'NotifyOutboundSpam'; Value = $(if ($null -eq ($policy.NotifyOutboundSpam)) { 'Not found' } else { $policy.NotifyOutboundSpam }); Pass = [bool]($policy.NotifyOutboundSpam -eq $true) }
        [pscustomobject]@{ Policy = $policy.Name; Setting = 'NotifyOutboundSpamRecipients'; Value = $(if (@($policy.NotifyOutboundSpamRecipients | Where-Object { $_ }).Count -eq 0) { 'Not set' } else { @($policy.NotifyOutboundSpamRecipients | Where-Object { $_ }) -join ', ' }); Pass = [bool](@($policy.NotifyOutboundSpamRecipients | Where-Object { $_ }).Count -gt 0) }
    }
    $testResult = $hasDefault -and @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The default outbound spam policy limits recipients, blocks the user when a limit is reached, turns on outbound spam notifications and names a notification recipient.'
    $failText = if (-not $hasDefault) { 'Expected one default outbound spam policy, but it was not found uniquely.' } else { 'The default outbound spam policy does not limit recipients, block the user, turn on outbound spam notifications or name a notification recipient as required.' }

    $resultMd = "| Policy | Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Policy) | $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
