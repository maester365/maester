function Test-MtCisaImpersonation {
    <#
    .SYNOPSIS
    Checks impersonation protection for configured sensitive users

    .DESCRIPTION
    User impersonation protection SHOULD be enabled for sensitive accounts.

    .EXAMPLE
    Test-MtCisaImpersonation

    Returns true if sensitive-user protection is enabled and at least one protected account is configured.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaImpersonation
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.2.1',
        Title = 'User impersonation protection SHOULD be enabled for sensitive accounts.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-phishing',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.2.1',
        Service = ('ExchangeOnline', 'Graph'),
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = Get-MtExo -Request AntiPhishPolicy

    $resultPolicies = $policies | Where-Object { `
        $_.Enabled -and `
        $_.ImpersonationProtectionState -eq "Automatic" -and `
        $_.EnableOrganizationDomainsProtection -and `
        $_.EnableTargetedDomainsProtection -and `
        $_.EnableTargetedUserProtection -and `
        @($_.TargetedUsersToProtect | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0
    }

    $standard = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($resultPolicies|Measure-Object).Count -ge 1)

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [impersonation protection enabled for configured sensitive users]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [impersonation protection enabled for configured sensitive users]($portalLink).`n`n%TestResult%"
    }

    $result = "| Policy | Status |`n"
    $result += "| --- | --- |`n"
    if ($standard) {
        $result += "| Standard | $passResult |`n"
    } else {
        $result += "| Standard | $failResult |`n"
    }
    if ($strict) {
        $result += "| Strict | $passResult |`n`n"
    } else {
        $result += "| Strict | $failResult |`n`n"
    }

    $result += "| Policy Name | Sensitive users protected | Result |`n"
    $result += "| --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        $targetedUsers = @($item.TargetedUsersToProtect | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if($item.Guid -in $resultPolicies.Guid){
            $result += "| $($item.Identity) | $($targetedUsers.Count) | $($passResult) |`n"
        }else{
            $result += "| $($item.Identity) | $($targetedUsers.Count) | $($failResult) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
