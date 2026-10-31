function Test-MtCisConnectionFilterSafeList {
    <#
    .SYNOPSIS
    Checks if connection filter IPs are allow listed

    .DESCRIPTION
    The connection filter should not have the safe list enabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.13, L1)

    .EXAMPLE
    Test-MtCisConnectionFilterSafeList

    Returns true if the safe list is not enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisConnectionFilterSafeList
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.13',
        Title = 'Ensure the connection filter safe list is off (Only Checks Default Policy)',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:2.1.13', 'nist-800-53-r5:AC-4'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'knussbaumer'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the Hosted Connection Filter policy...'
    $defaultPolicies = @(Get-MtExo -Request HostedConnectionFilterPolicy | Where-Object { $_.IsDefault -eq $true })
    if ($defaultPolicies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No default connection filter policy was returned; compliance could not be established.'
        return $false
    }
    if ($defaultPolicies.Count -ne 1) {
        Add-MtTestResultDetail -Result "Expected one default connection filter policy, found $($defaultPolicies.Count)."
        return $false
    }

    $safeListProperty = $defaultPolicies[0].PSObject.Properties['EnableSafeList']
    if ($null -eq $safeListProperty) {
        Add-MtTestResultDetail -Result 'The default connection filter policy did not return EnableSafeList; compliance could not be established.'
        return $false
    }

    Write-Verbose 'Check if the Connection Filter safe list is enabled'
    $result = $safeListProperty.Value

    # We need to Invert the $result that we don't need to change the Markdown. False in $result is good and True is bad
    $testResult = ($result -is [bool] -and -not $result) -or ([string]$result -ieq 'False')

    if ($testResult) {
        $testResultMarkdown = 'Well done. The connection filter safe list was not enabled ✅'
    } else {
        $testResultMarkdown = 'The connection filter safe list was enabled ❌'
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
