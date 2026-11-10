function Test-MtCisaAntiSpamAllowList {
    <#
    .SYNOPSIS
    Checks state of anti-spam policies

    .DESCRIPTION
    IP allow lists SHOULD NOT be created.

    .EXAMPLE
    Test-MtCisaAntiSpamAllowList

    Returns true if no allowed IPs in anti-spam policy

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAntiSpamAllowList
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.8.1',
        Title = 'IP allow lists SHOULD NOT be created.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.8.1',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtExo -Request HostedConnectionFilterPolicy)

    $resultPolicy = @($policies | Where-Object {`
        ($_.IPAllowList | Measure-Object).Count -gt 0
    })

    $testResult = $policies.Count -gt 0 -and $resultPolicy.Count -eq 0

    $portalLink = "https://security.microsoft.com/antispam"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant does not have any [Anti-spam IP allow lists]($portalLink)."
    } elseif ($policies.Count -eq 0) {
        $testResultMarkdown = "No connection filter policy was returned. Verify the connection to Exchange Online and confirm that the policy data is available."
    } else {
        $testResultMarkdown = "Your tenant has [Anti-spam IP allow lists]($portalLink).`n`n%TestResult%"
        $resultPolicy | ForEach-Object {
            $result = "* $($_.Name)`n"
            $_.IPAllowList | ForEach-Object {`
                    $result += "  * $_`n"
            }
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
