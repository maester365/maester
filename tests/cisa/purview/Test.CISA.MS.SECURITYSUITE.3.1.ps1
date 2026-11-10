function Test-MtCisaDlpSensitiveInformation {
    <#
    .SYNOPSIS
    Checks whether enabled DLP policies protect the required sensitive information types.

    .DESCRIPTION
    Enabled DLP policies must protect credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN).

    .EXAMPLE
    Test-MtCisaDlpSensitiveInformation

    Returns true when enabled policies have non-disabled rules that collectively protect all three required sensitive information types.

    .LINK
    https://maester.dev/docs/tests/CISA.MS.SECURITYSUITE.3.1
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.3.1',
        Title = 'A DLP policy SHALL be configured to protect PII and sensitive information, as defined by the agency, blocking at a minimum: credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN).',
        Product = 'purview',
        RelatedProduct = 'exchange',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1213', 'T1530', 'T1567'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.3.1',
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        License = 'EXCHANGE_DLP',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $sensitiveRules = @(Get-MtCisaSensitiveDlpRule)
    $requiredTypes = @(
        'Credit Card Number'
        'U.S. Social Security Number (SSN)'
        'U.S. Individual Taxpayer Identification Number (ITIN)'
    )
    $coveredTypes = @($sensitiveRules | ForEach-Object { $_.SensitiveTypes } | Select-Object -Unique)
    $missingTypes = @($requiredTypes | Where-Object { $_ -notin $coveredTypes })
    $testResult = $missingTypes.Count -eq 0

    $result = "| Sensitive information type | Matching enabled policy rules | Result |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($sensitiveType in $requiredTypes) {
        $matchingRules = @(
            $sensitiveRules | Where-Object { $sensitiveType -in $_.SensitiveTypes } |
                ForEach-Object { "$($_.Policy.Identity): $($_.Rule.Name)" }
        )
        $status = if ($sensitiveType -in $coveredTypes) { '✅ Pass' } else { '❌ Fail' }
        $ruleNames = if ($matchingRules.Count -gt 0) { $matchingRules -join ', ' } else { 'None' }
        $result += "| $sensitiveType | $ruleNames | $status |`n"
    }

    $message = if ($testResult) {
        "Well done. Enabled DLP policies protect all required sensitive information types.`n`n%TestResult%"
    } else {
        "Configure an enabled DLP policy with non-disabled rules that protect the missing sensitive information types: $($missingTypes -join ', ').`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
