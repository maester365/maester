function Test-MtCisaDlp {
    <#
    .SYNOPSIS
    Checks state of DLP for EXO

    .DESCRIPTION
    A DLP solution SHALL be used.

    .EXAMPLE
    Test-MtCisaDlp

    Returns true if

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaDlp
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.8.1',
        Title = 'A DLP solution SHALL be used.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.8.1'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        CompatibleLicense = 'EXCHANGE_DLP',
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = Get-MtExo -Request DlpCompliancePolicy | Where-Object { $_.ExchangeLocation.DisplayName -contains "All" }

    $resultPolicies = $policies | Where-Object {`
        $_.Workload -like "*Exchange*" -and `
        -not $_.IsSimulationPolicy -and `
        $_.Enabled
    }

    $testResult = ($resultPolicies | Measure-Object).Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalossprevention/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [Purview Data Loss Prevention Policies]($portalLink) enabled.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [Purview Data Loss Prevention Policies]($portalLink) enabled.`n`n%TestResult%"
    }

    $result = ''
    if ($policies) {
        $passResult = "✅ Pass"
        $failResult = "❌ Fail"
        $result = "| Name | Status | Description |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($item in ($policies | Sort-Object -Property name)) {
            $itemResult = $failResult
            if($item.Guid -in $resultPolicies.Guid){
                $itemResult = $passResult
            }
            $result += "| $($item.name) | $($itemResult) | $($item.comment) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
