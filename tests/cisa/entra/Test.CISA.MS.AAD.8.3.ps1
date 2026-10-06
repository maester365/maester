function Test-MtCisaCrossTenantInboundDefault {
    <#
    .SYNOPSIS
    Checks cross-tenant default inbound access configuration

    .DESCRIPTION
    Guest invites SHOULD only be allowed to specific external domains that have been authorized by the agency for legitimate business purposes.

    .EXAMPLE
    Test-MtCisaCrossTenantInboundDefault

    Returns true if cross-tenant default inbound access is set to block.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaCrossTenantInboundDefault
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.8.3',
        Title = 'Guest invites SHOULD only be allowed to specific external domains that have been authorized by the agency for legitimate business purposes.',
        Severity = 'Medium',
        Category = 'CISA',
        Tag = ('Entra ID Free', 'MS.AAD', 'MS.AAD.8.3'),
        Service = 'Graph',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Invoke-MtGraphRequest -RelativeUri "policies/crossTenantAccessPolicy/default"

    $testResult = ($policy | Where-Object {`
        $_.b2bCollaborationInbound.usersAndGroups.accessType -eq "blocked" -and `
        $_.b2bCollaborationInbound.applications.accessType -eq "blocked"
    }|Measure-Object).Count -eq 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant's default cross-tenant inbound access policy is set to block:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant's default cross-tenant inbound access policy is not set to block:`n`n%TestResult%"
    }

    $portalLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/InboundAccessSettings.ReactView/isDefault~/true/name//id/"
    $result = "| External Users & Groups | Applications |`n"
    $result += "| --- | --- |`n"
    $usersAndGroups = $applications = "❌ Fail"
    if($policy.b2bCollaborationInbound.usersAndGroups.accessType -eq "blocked"){
        $usersAndGroups = "[✅ Pass]($portalLink)"
    }
    if($policy.b2bCollaborationInbound.applications.accessType -eq "blocked"){
        $applications = "[✅ Pass]($portalLink)"
    }
    $result += "| $usersAndGroups | $applications |`n"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
