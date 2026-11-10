function Test-MtCisaDlpBlocksSensitiveInformation {
    <#
    .SYNOPSIS
    Checks whether full-protection DLP rules block access for everyone.

    .DESCRIPTION
    DLP rules protecting credit card numbers, ITINs, and SSNs SHOULD block access for everyone.

    .EXAMPLE
    Test-MtCisaDlpBlocksSensitiveInformation

    Returns true when every non-disabled full-protection rule in an enabled policy blocks access for everyone.

    .LINK
    https://maester.dev/docs/tests/CISA.MS.SECURITYSUITE.3.3
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.3.3',
        Title = 'The action for the DLP policy SHOULD be set to block sharing sensitive information with everyone.',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1567', 'T1530', 'T1213'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.3.3',
        Service = 'SecurityCompliance',
        License = 'EXCHANGE_DLP',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $fullProtectionRules = @(Get-MtCisaSensitiveDlpRule | Where-Object { $_.SensitiveTypes.Count -eq 3 })
    $testResult = $fullProtectionRules.Count -gt 0 -and @(
        $fullProtectionRules | Where-Object {
            $_.Rule.BlockAccess -ne $true -or $_.Rule.BlockAccessScope -ne 'All'
        }
    ).Count -eq 0

    $result = "| Policy | Rule | Block access | Scope | Result |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($entry in $fullProtectionRules | Sort-Object -Property { $_.Policy.Identity }, { $_.Rule.Name }) {
        $status = if ($entry.Rule.BlockAccess -eq $true -and $entry.Rule.BlockAccessScope -eq 'All') { '✅ Pass' } else { '❌ Fail' }
        $blockAccess = if ($entry.Rule.BlockAccess -eq $true) { 'Enabled' } else { 'Disabled' }
        $scope = if ($entry.Rule.BlockAccessScope) { $entry.Rule.BlockAccessScope } else { 'Not configured' }
        $result += "| $($entry.Policy.Identity) | $($entry.Rule.Name) | $blockAccess | $scope | $status |`n"
    }

    if ($fullProtectionRules.Count -eq 0) {
        $message = "No non-disabled DLP rule in an enabled policy protects all three required sensitive information types.`n`n%TestResult%"
    } elseif ($testResult) {
        $message = "Well done. Every non-disabled full-protection DLP rule in an enabled policy blocks access for everyone.`n`n%TestResult%"
    } else {
        $message = "Configure every non-disabled DLP rule in an enabled policy that protects all three required sensitive information types to block access for everyone.`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
