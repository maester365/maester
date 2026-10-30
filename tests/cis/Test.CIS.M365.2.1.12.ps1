function Test-MtCisHostedConnectionFilterPolicy {
    <#
    .SYNOPSIS
    Checks if connection filter IPs are allow listed

    .DESCRIPTION
    The connection filter should not have allow listed IPs
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.12, L1)

    .EXAMPLE
    Test-MtCisHostedConnectionFilterPolicy

    Returns true if the IP allow list is empty

    .LINK
    https://maester.dev/docs/commands/Test-MtCisHostedConnectionFilterPolicy
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.12',
        Title = 'Ensure the connection filter IP allow list is not used (Only Checks Default Policy)',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:2.1.12', 'nist-800-53-r5:AC-4'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'knussbaumer'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the Hosted Connection Filter policy...'
    $defaultPolicies = @(Get-MtExo -Request HostedConnectionFilterPolicy | Where-Object { $_.IsDefault -eq $true })
    if ($defaultPolicies.Count -ne 1) {
        Add-MtTestResultDetail -Result "Expected one default connection filter policy, found $($defaultPolicies.Count)."
        return $false
    }

    $allowListProperty = $defaultPolicies[0].PSObject.Properties['IPAllowList']
    if ($null -eq $allowListProperty) {
        Add-MtTestResultDetail -Result 'The default connection filter policy did not return IPAllowList; compliance could not be established.'
        return $false
    }

    Write-Verbose 'Check if the Connection Filter IP allow list is empty'
    $ipAllowList = @($allowListProperty.Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $testResult = $ipAllowList.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = 'Well done. The connection filter IP allow list was empty ✅'
    } else {
        $testResultMarkdown = 'The connection filter IP allow list was not empty ❌'
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
