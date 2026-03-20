<#
.SYNOPSIS
    Checks if OneDrive external sharing is limited

.DESCRIPTION
    External sharing for OneDrive SHALL be limited to Existing guests or Only people in your organization.

.EXAMPLE
    Test-MtCisaSpoOneDriveSharing

    Returns true if OneDrive sharing is restricted to existing guests or disabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoOneDriveSharing
#>
function Test-MtCisaSpoOneDriveSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($null -eq $spoTenant) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online PowerShell module is not connected. Run Connect-SPOService first."
        return $null
    }

    $oneDriveSharing = $spoTenant.OneDriveSharingCapability

    $testResult = $oneDriveSharing -in @('ExistingExternalUserSharingOnly', 'Disabled')

    if ($testResult) {
        $testResultMarkdown = "Well done. OneDrive external sharing is restricted to **$oneDriveSharing**.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "OneDrive external sharing is set to **$oneDriveSharing**. It should be set to **ExistingExternalUserSharingOnly** or **Disabled**.`n`n%TestResult%"
    }

    $result = "| Setting | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| OneDriveSharingCapability | $oneDriveSharing |`n"

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
