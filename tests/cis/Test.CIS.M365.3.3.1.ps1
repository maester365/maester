function Test-MtCisSensitivityLabelPoliciesPublished {
    <#
    .SYNOPSIS
        Checks that at least one sensitivity label policy is published.

    .DESCRIPTION
        Checks that at least one policy that publishes sensitivity labels to users exists, so that users can classify and protect their documents and email.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.3.1, L1)

    .EXAMPLE
        Test-MtCisSensitivityLabelPoliciesPublished

        Returns true if at least one sensitivity label policy is published.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.3.3.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.3.1',
        Title = 'Ensure Information Protection sensitivity label policies are published',
        Product = 'purview',
        Feature = 'information-protection',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Control = ('cis-m365:3.3.1', 'nist-800-53-r5:AC-4'),
        Service = 'SecurityCompliance',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting label policies...'
    $labelPolicies = @(Get-MtExo -Request LabelPolicy | Where-Object { $_.Type -eq 'PublishedSensitivityLabel' })
    $testResult = $labelPolicies.Count -ge 1

    $passText = "$($labelPolicies.Count) sensitivity label policy(ies) are published."
    $failText = 'No sensitivity label policy is published.'

    $resultMd = "| Label policy | Result |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($policy in $labelPolicies) {
        $resultMd += "| $($policy.Name) | ✅ Pass |`n"
    }
    if (-not $testResult) {
        $resultMd += "| None found | ❌ Fail |`n"
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