function Test-MtDisaPasswordLifetime {
    <#
    .SYNOPSIS
    Checks that passwords expire after 180 days or less on every verified, managed domain.

    .DESCRIPTION
    The DISA Microsoft Entra ID STIG (V-270239) asks for a maximum password lifetime of 180 days. The password
    expiration period is stored per domain (passwordValidityPeriodInDays); the STIG's note points to Get-MgDomain to
    read it.

    This check reads every verified domain that is managed (not federated) and fails when one of them never expires
    passwords or sets a period longer than the given number of days (180 by default). A domain that stores no
    period is reported for review: the STIG states that the Microsoft Entra default is 90 days, but tenants
    created more recently do not expire passwords by default, and the API does not say which applies.

    CIS.M365.1.3.1 reads the same setting and asks for the opposite, passwords that never expire, following
    NIST SP 800-63B. A tenant passes one of the two tests at most.

    .EXAMPLE
    Test-MtDisaPasswordLifetime

    Returns true when every verified, managed domain expires passwords after 180 days or less.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270239
    #>
    [MaesterTest(
        Id = 'DISA.V-270239',
        Title = 'Microsoft Entra ID must enforce a 180-day maximum password lifetime restriction.',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Domain',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = 'disa-stig-entra-id:V-270239',
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Longest password lifetime that is allowed, in days.
        [ValidateRange(1, 730)]
        [int] $MaximumPasswordAgeDays = 180
    )

    $domains = @(Get-MtDomainPasswordValidity)
    $applicable = @($domains | Where-Object IsApplicable)
    if ($applicable.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }
    $failing = @($applicable | Where-Object { $_.IsSet -and ($_.NeverExpires -or $_.ValidityDays -gt $MaximumPasswordAgeDays) })
    $unset = @($applicable | Where-Object { -not $_.IsSet })
    $testResult = $failing.Count -eq 0

    $table = "| Domain | Password lifetime | Result |`n| --- | --- | --- |`n"
    foreach ($domain in $domains) {
        $value = if (-not $domain.IsSet) { 'Not set' } elseif ($domain.NeverExpires) { 'Never expires' } else { "$($domain.ValidityDays) days" }
        $result = if (-not $domain.IsApplicable) { '⏭️ Skip' } elseif ($domain -in $failing) { '❌ Fail' } elseif ($domain -in $unset) { '❔ Review' } else { '✅ Pass' }
        $table += "| $($domain.Id) | $value | $result |`n"
    }

    if (-not $testResult) {
        $testResultMarkdown = "$($failing.Count) verified, managed domain(s) let passwords live longer than $MaximumPasswordAgeDays days, or never expire them.`n`n$table"
        Add-MtTestResultDetail -Result $testResultMarkdown
    } elseif ($unset.Count -gt 0) {
        $testResultMarkdown = "$($unset.Count) domain(s) store no password expiration period, so the API does not show which lifetime applies. Set the period explicitly to $MaximumPasswordAgeDays days or less.`n`n$table"
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    } else {
        $testResultMarkdown = "Well done. Passwords expire after $MaximumPasswordAgeDays days or less on every verified, managed domain.`n`n$table"
        Add-MtTestResultDetail -Result $testResultMarkdown
    }
    return $testResult
}
