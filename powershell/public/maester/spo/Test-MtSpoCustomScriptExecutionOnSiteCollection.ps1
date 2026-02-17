<#
.SYNOPSIS
    7.3.4 (L1) Ensure custom script execution is restricted on site collections

.DESCRIPTION
    This setting controls custom script execution on a particular site (previously called "site collection").
    Custom scripts can allow users to change the look, feel and behavior of sites and pages. Every script that runs in a SharePoint page (whether it's an HTML page in a document library or a JavaScript in a Script Editor Web Part) always runs in the context of the user visiting the page and the SharePoint application. This means:
    * Scripts have access to everything the user has access to.
    * Scripts can access content across several Microsoft 365 services and even beyond with Microsoft Graph integration. The recommended state is DenyAddAndCustomizePages set to $true.

.EXAMPLE
    Test-MtSpoCustomScriptExecutionOnSiteCollection

    Returns true if custom script execution is restricted on all site collections, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoCustomScriptExecutionOnSiteCollection
#>
function Test-MtSpoCustomScriptExecutionOnSiteCollection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link type in SharePoint Online..."

    $return = $true
    try {
        $noncompliantSites = Get-SPOSite | Where-Object { $_.DenyAddAndCustomizePages -eq "Disabled" -and $_.Url -notlike "*-my.sharepoint.com/" }
        if ($noncompliantSites | Measure-Object | Select-Object -ExpandProperty Count -eq 0) {
            $testResult = "Well done. Custom script execution is restricted on all site collections."
        } else {
            $result = "Title | URL | DenyAddAndCustomizePages |`n"
            $result += "--- | --- | --- |`n"
            foreach ($site in $noncompliantSites) {
                $result += "$($site.Title) | $($site.Url) | $($site.DenyAddAndCustomizePages) |`n"
            }
            $testResult = "Custom script execution is not restricted on the following site collections:`n`n$($result)"
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}