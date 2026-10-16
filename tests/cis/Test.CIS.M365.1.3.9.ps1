function Test-MtCisSharedBookingsRestricted {
    <#
    .SYNOPSIS
        Checks that creating shared Bookings pages is restricted, or that Bookings is turned off.

    .DESCRIPTION
        Checks that the default Outlook on the web mailbox policy does not let all users create shared Bookings mailboxes, or that Microsoft Bookings is disabled for the whole organisation.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.9, L1)

    .EXAMPLE
        Test-MtCisSharedBookingsRestricted

        Returns true if shared Bookings page creation is restricted or Bookings is disabled.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.1.3.9
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.9',
        Title = 'Ensure shared bookings pages are restricted to select users',
        Product = 'microsoft-365',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:1.3.9', 'nist-800-53-r5:AC-3'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $owaPolicy = @(Get-MtExo -Request OwaMailboxPolicy) | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1
    $orgConfig = Get-MtExo -Request OrganizationConfig

    $checks = @(
        [pscustomobject]@{ Setting = 'Bookings enabled for the organization'; Value = $(if ($null -eq ($orgConfig.BookingsEnabled)) { 'Not found' } else { $orgConfig.BookingsEnabled }); Pass = [bool]($orgConfig.BookingsEnabled -eq $false) }
        [pscustomobject]@{ Setting = 'Users can create shared Bookings pages (default OWA policy)'; Value = $(if ($null -eq ($owaPolicy.BookingsMailboxCreationEnabled)) { 'Not found' } else { $owaPolicy.BookingsMailboxCreationEnabled }); Pass = [bool]($owaPolicy.BookingsMailboxCreationEnabled -eq $false) }
    )
    $testResult = @($checks | Where-Object { $_.Pass }).Count -gt 0

    $passText = 'Shared Bookings page creation is restricted or Bookings is disabled.'
    $failText = 'Every user can create shared Bookings pages, and Bookings is enabled.'

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