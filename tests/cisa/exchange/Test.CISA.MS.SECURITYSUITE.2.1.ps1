function Test-MtCisaImpersonation {
    <#
    .SYNOPSIS
    Checks impersonation protection for configured sensitive users

    .DESCRIPTION
    User impersonation protection SHOULD be enabled for every configured sensitive account.

    .PARAMETER SensitiveUsers
    Sensitive users to require in the policy, as email addresses or display name and email separated by a semicolon.

    .EXAMPLE
    Test-MtCisaImpersonation

    Returns true if one enabled policy covering all recipients protects every configured sensitive user.

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
    param(
        [string[]] $SensitiveUsers = @()
    )

    $configuredUsers = @(
        $SensitiveUsers |
            ForEach-Object {
                $parts = ([string]$_).Split(';', 2)
                $email = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
                $email.Trim().ToLowerInvariant()
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    $policies = @(Get-MtCisaEffectiveAntiPhishPolicy)
    $resultPolicies = @(
        $policies | Where-Object {
            $protectedUsers = @(
                $_.TargetedUsersToProtect |
                    ForEach-Object {
                        $parts = ([string]$_).Split(';', 2)
                        $email = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
                        $email.Trim().ToLowerInvariant()
                    } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )
            $missingUsers = @($configuredUsers | Where-Object { $_ -notin $protectedUsers })
            $action = ([string]$_.TargetedUserProtectionAction).Trim().ToLowerInvariant()

            $configuredUsers.Count -gt 0 -and
            $_.EnableTargetedUserProtection -eq $true -and
            -not [string]::IsNullOrWhiteSpace($action) -and
            $action -notin @('noaction', 'bccmessage') -and
            $missingUsers.Count -eq 0
        }
    )
    $testResult = $resultPolicies.Count -gt 0

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. An enabled anti-phishing policy applying to all recipients protects every configured sensitive user. [Review anti-phishing policies]($portalLink).`n`n%TestResult%"
    } elseif ($configuredUsers.Count -eq 0) {
        $testResultMarkdown = "Configure the SensitiveUsers parameter with the agency's sensitive accounts, then enable user impersonation protection for each one in an anti-phishing policy that applies to all recipients. [Review anti-phishing policies]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Enable user impersonation protection for every configured sensitive user in an anti-phishing policy that applies to all recipients, using an action other than NoAction or BccMessage. [Review anti-phishing policies]($portalLink).`n`n%TestResult%"
    }

    $result = if ($configuredUsers.Count -eq 0) {
        "No sensitive users are configured for this test."
    } elseif ($policies.Count -eq 0) {
        "No enabled anti-phishing policy covering all recipients was found."
    } else {
        $policyResults = foreach ($policy in $policies | Sort-Object -Property Identity) {
            $targetedUsers = @(
                $policy.TargetedUsersToProtect |
                    ForEach-Object {
                        $parts = ([string]$_).Split(';', 2)
                        $email = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
                        $email.Trim().ToLowerInvariant()
                    } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )
            $missingUsers = @($configuredUsers | Where-Object { $_ -notin $targetedUsers })
            $status = if ($policy.Identity -in $resultPolicies.Identity) { $passResult } else { $failResult }
            "- **$($policy.Identity):** $status; configured users missing from protection: $(if ($missingUsers.Count -gt 0) { $missingUsers -join ', ' } else { 'none' })."
        }
        $policyResults -join "`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
