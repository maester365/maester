function Test-MtCisZAP {
    <#
    .SYNOPSIS
    Checks if the Zero-hour auto purge (ZAP) for Microsoft Teams is enabled

    .DESCRIPTION
    Zero-hour auto purge (ZAP) should be enabled for Microsoft Teams
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.4, L1)

    .EXAMPLE
    Test-MtCisZAP

    Returns true if Zero-hour auto purge (ZAP) is enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisZAP
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.4.4',
        Title = 'Ensure Zero-hour auto purge for Microsoft Teams is on (Only Checks ZAP is enabled)',
        Product = 'defender',
        RelatedProduct = 'teams',
        Feature = 'zero-hour-auto-purge',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:2.4.4', 'nist-800-53-r5:SI-3'),
        Service = 'ExchangeOnline',
        License = 'THREAT_INTELLIGENCE',
        Author = 'NZLostboy',
        Contributor = 'Korthal-Maiyn'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the Teams protection policy and rule'
    $policies = @(Get-MtExo -Request TeamsProtectionPolicy)
    $rules = @(Get-MtExo -Request TeamsProtectionPolicyRule)

    $testResult = $policies.Count -gt 0 -and @($policies | Where-Object { $_.ZapEnabled -ne $true }).Count -eq 0

    $exclusions = foreach ($rule in $rules) {
        foreach ($property in 'ExceptIfSentTo', 'ExceptIfSentToMemberOf', 'ExceptIfRecipientDomainIs') {
            $values = @($rule.$property | Where-Object { $_ })
            if ($values.Count -gt 0) {
                [pscustomobject]@{ Exception = $property; Values = $values -join ', ' }
            }
        }
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has Zero-hour auto purge (ZAP) enabled for Microsoft Teams.`n`n%TestResult%"
    }
    elseif ($policies.Count -eq 0) {
        $testResultMarkdown = "No Teams protection policy was returned, so Zero-hour auto purge (ZAP) for Microsoft Teams could not be confirmed.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant does not have Zero-hour auto purge (ZAP) enabled for Microsoft Teams.`n`n%TestResult%"
    }

    $resultMd = "| Policy | Zero-hour auto purge (ZAP) | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($policy in $policies) {
        $resultMd += "| $($policy.Name) | $($policy.ZapEnabled) | $(if ($policy.ZapEnabled -eq $true) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }
    if ($policies.Count -eq 0) {
        $resultMd += "| Not found | | ❌ Fail |`n"
    }

    if (@($exclusions).Count -gt 0) {
        $resultMd += "`nReview these exclusions and confirm that each one is justified. These exceptions match recipient conditions: if any recipient in a chat is not excluded, ZAP can still block the message for everyone. ZAP takes no action only when all recipients are excluded.`n`n"
        $resultMd += "| Exclusion | Participants |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($exclusion in $exclusions) {
            $resultMd += "| $($exclusion.Exception) | $($exclusion.Values) |`n"
        }
    }
    else {
        $resultMd += "`nNo participants are excluded from Teams protection.`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
