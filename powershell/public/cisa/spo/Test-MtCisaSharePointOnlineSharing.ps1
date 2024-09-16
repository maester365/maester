<#
.SYNOPSIS
    Checks state of SharePoint Online sharing

.DESCRIPTION
    External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization.

.EXAMPLE
    Test-MtCisaSharePointOnlineSharing

    Returns true if sharing is restricted

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSharePointOnlineSharing
#>
function Test-MtCisaSharePointOnlineSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Invoke-MtGraphRequest -RelativeUri "admin/sharepoint/settings" -ApiVersion "v1.0"

    $resultPolicy = $policy | Where-Object {
        $_.sharingCapability -in @("disabled","existingExternalUserSharingOnly")
    }

    $testResult = ($resultPolicy | Measure-Object).Count -gt 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant restricts SharePoint Online sharing."
    } else {
        $testResultMarkdown = "Your tenant does not restrict SharePoint Online sharing.`n`n%TestResult%"
        $policy | ForEach-Object {
            $result = "* $($_.sharingCapability)`n"
            $result | Out-Null
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}