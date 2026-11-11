function Test-MtCisPasswordExpiry {
    <#
    .SYNOPSIS
    Checks if passwords are set to expire

    .DESCRIPTION
    Passwords should not be set to expire
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.1, L1)

    .EXAMPLE
    Test-MtCisPasswordExpiry

    Returns true if no passwords are set to expire

    .LINK
    https://maester.dev/docs/commands/Test-MtCisPasswordExpiry
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.1',
        Title = 'Ensure the ''Password expiration policy'' is set to ''Set passwords to never expire (recommended)''',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:1.3.1', 'nist-800-53-r5:IA-5(1)'),
        Service = 'Graph',
        Author = 'NZLostboy',
        Contributor = ('merill', 'brianreidc7', 'blindzero')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Get domain details for the password expiry period'
    # Password policy checks apply only to managed and verified domains. A domain that stores no period does not expire passwords.
    $domains = @(Get-MtDomainPasswordValidity)
    $result = @($domains | Where-Object { $_.IsApplicable -and $_.IsSet -and -not $_.NeverExpires })

    $testResult = ($result | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant passwords are not set to expire on all your 'managed' and 'verified' domains:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has 1 or more 'managed' and 'verified' domains which expire passwords:`n`n%TestResult%"
    }

    $resultMd = "| Domain | Result |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $domains) {
        $itemResult = '❌ Fail'
        if (-not $item.IsApplicable) {
            $itemResult = '⏭️ Skip'
        } elseif ($item.Id -notin $result.Id) {
            $itemResult = '✅ Pass'
        }
        $resultMd += "| $($item.Id) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
