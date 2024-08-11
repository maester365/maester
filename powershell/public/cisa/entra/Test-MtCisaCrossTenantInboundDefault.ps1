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
function Test-MtCisaCrossTenantInboundDefault {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

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