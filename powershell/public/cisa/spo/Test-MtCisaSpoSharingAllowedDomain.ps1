<#
.SYNOPSIS
    Checks state of SharePoint Online sharing

.DESCRIPTION
    External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs.

.EXAMPLE
    Test-MtCisaSharePointOnlineSharingAllowedDomains

    Returns true if sharing uses restricted domains

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSharePointOnlineSharingAllowedDomain
#>
function Test-MtCisaSharePointOnlineSharingAllowedDomain {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Invoke-MtGraphRequest -RelativeUri "admin/sharepoint/settings" -ApiVersion "v1.0"

    if($policy.sharingCapability -eq "disabled"){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online external sharing is disabled."
        return $null
    }

    $resultPolicy = $policy.sharingAllowedDomainList

    $testResult = ($resultPolicy | Measure-Object).Count -gt 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant restricts SharePoint Online sharing to specific domains.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not restrict SharePoint Online sharing to specific domains."
    }

    $resultPolicy | ForEach-Object {
        $result = "* $_`n"
        $result | Out-Null
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}