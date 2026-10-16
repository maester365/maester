function Test-MtCisOutboundSpamLimits {
    <#
    .SYNOPSIS
        Checks that the default outbound spam policy sets recipient limits and blocks the user when they are reached.

    .DESCRIPTION
        Checks the default outbound spam filter policy and passes when the external recipients per hour, internal recipients per hour and total recipients per day limits are set, within the allowed maximum, and the action when a limit is reached is to restrict the user from sending mail.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.15, L1)

    .EXAMPLE
        Test-MtCisOutboundSpamLimits

        Returns true if the default outbound spam policy has limits and blocks the user when they are exceeded.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.1.15
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.15',
        Title = 'Ensure outbound anti-spam message limits are in place',
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

    $policy = @(Get-MtExo -Request HostedOutboundSpamFilterPolicy) | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1

    $checks = @(
        [pscustomobject]@{ Setting = 'RecipientLimitExternalPerHour'; Value = $(if ($null -eq ($policy.RecipientLimitExternalPerHour)) { 'Not found' } else { $policy.RecipientLimitExternalPerHour }); Pass = [bool]($policy.RecipientLimitExternalPerHour -gt 0 -and $policy.RecipientLimitExternalPerHour -le $MaximumExternalRecipientsPerHour) }
        [pscustomobject]@{ Setting = 'RecipientLimitInternalPerHour'; Value = $(if ($null -eq ($policy.RecipientLimitInternalPerHour)) { 'Not found' } else { $policy.RecipientLimitInternalPerHour }); Pass = [bool]($policy.RecipientLimitInternalPerHour -gt 0 -and $policy.RecipientLimitInternalPerHour -le $MaximumInternalRecipientsPerHour) }
        [pscustomobject]@{ Setting = 'RecipientLimitPerDay'; Value = $(if ($null -eq ($policy.RecipientLimitPerDay)) { 'Not found' } else { $policy.RecipientLimitPerDay }); Pass = [bool]($policy.RecipientLimitPerDay -gt 0 -and $policy.RecipientLimitPerDay -le $MaximumRecipientsPerDay) }
        [pscustomobject]@{ Setting = 'ActionWhenThresholdReached'; Value = $(if ($null -eq ($policy.ActionWhenThresholdReached)) { 'Not found' } else { $policy.ActionWhenThresholdReached }); Pass = [bool]($policy.ActionWhenThresholdReached -eq 'BlockUser') }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The default outbound spam policy limits recipients and blocks the user when a limit is reached.'
    $failText = 'The default outbound spam policy does not limit recipients as required.'

    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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