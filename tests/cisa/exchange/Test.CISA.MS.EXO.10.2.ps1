function Test-MtCisaMalwareAction {
    <#
    .SYNOPSIS
    Checks state of preset security policies

    .DESCRIPTION
    Emails identified as containing malware SHALL be quarantined or dropped.

    .EXAMPLE
    Test-MtCisaMalwareAction

    Returns true if standard and strict protection is on

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaMalwareAction
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.10.2',
        Title = 'Emails identified as containing malware SHALL be quarantined or dropped.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.10.2'),
        Service = ('ExchangeOnline', 'Graph'),
        Author = 'soulemike',
        Contributor = 'JeanPhilippeGeorge'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 0
    $policies = Get-MtExoThreatPolicyMalware

    $failingPolicies = $policies | Where-Object { $_.IsEnabled -and $_.QuarantineTag -ne "AdminOnlyAccessPolicy" }
    $testResult = ($failingPolicies | Measure-Object).Count -eq 0

    $portalLink = "https://security.microsoft.com/antimalwarev2"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"

    $result = "| Policy name | Enabled | Quarantine Tag | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $policies) {
        if (-not $item.IsEnabled) {
            $result += "| $($item.Identity) | $false | $($item.QuarantineTag) | $($skipResult) |`n"
        } elseif ($item.QuarantineTag -eq "AdminOnlyAccessPolicy") {
            $result += "| $($item.Identity) | $true | $($item.QuarantineTag) | $($passResult) |`n"
        } else {
            $result += "| $($item.Identity) | $true | $($item.QuarantineTag) | $($failResult) |`n"
        }
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. All the anti-malware policies in your tenant have the property QuarantinePolicy set to 'AdminOnlyAccessPolicy' ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have all the anti-malware policies with the property QuarantinePolicy set to 'AdminOnlyAccessPolicy' ($portalLink).`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
