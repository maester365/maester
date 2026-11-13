function Test-MtCisaImpersonationTip {
    <#
    .SYNOPSIS
    Checks user safety tips in anti-phishing policies

    .DESCRIPTION
    User warnings comparable to EOP safety tips SHOULD be enabled on an effective policy that applies to all recipients.

    .EXAMPLE
    Test-MtCisaImpersonationTip

    Returns true if an all-recipient preset policy or custom policy enables all required user safety tips.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaImpersonationTip
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.2.4',
        Title = 'User warnings, comparable to the user safety tips included with EOP, SHOULD be displayed.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-phishing',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.2.4',
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtCisaEffectiveAntiPhishPolicy)
    $requiredTips = @(
        'EnableFirstContactSafetyTips',
        'EnableSimilarUsersSafetyTips',
        'EnableSimilarDomainsSafetyTips',
        'EnableUnusualCharactersSafetyTips',
        'EnableViaTag',
        'EnableUnauthenticatedSender'
    )
    $customPolicies = @(
        $policies | Where-Object {
            $policy = $_
            $missingTips = @($requiredTips | Where-Object { -not $policy.$_ })
            $policy.Identity -notmatch '(?i)(Standard|Strict) Preset Security Policy' -and
            $missingTips.Count -eq 0
        }
    )
    $presetPolicies = @(
        $policies | Where-Object { $_.Identity -match '(?i)(Standard|Strict) Preset Security Policy' }
    )
    $testResult = $customPolicies.Count -gt 0 -or $presetPolicies.Count -gt 0

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"

    if ($testResult) {
        $testResultMarkdown = "Well done. User safety tips are enabled by an all-recipient preset policy or a custom anti-phishing policy. [Review anti-phishing policies]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Enable all required user safety tips in a custom anti-phishing policy that applies to all recipients, or ensure an all-recipient Standard or Strict preset policy is enabled. [Review anti-phishing policies]($portalLink).`n`n%TestResult%"
    }

    $policyResults = foreach ($policy in $policies | Sort-Object -Property Identity) {
        $missingTips = @($requiredTips | Where-Object { -not $policy.$_ })
        if ($policy.Identity -match '(?i)(Standard|Strict) Preset Security Policy') {
            "- **$($policy.Identity):** preset policy applies to all recipients."
        } elseif ($missingTips.Count -eq 0) {
            "- **$($policy.Identity):** all required safety tips are enabled."
        } else {
            "- **$($policy.Identity):** missing $($missingTips -join ', ')."
        }
    }
    if ($presetPolicies.Count -gt 0) {
        $policyResults += '- An enabled Standard or Strict preset policy rule covers all recipients.'
    } elseif ($policyResults.Count -eq 0) {
        $policyResults = @('No all-recipient anti-phishing policy was found.')
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', ($policyResults -join "`n")

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
