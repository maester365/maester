﻿<#
.SYNOPSIS
Checks if safe links for office applications are Enabled

.DESCRIPTION
Safe links should be enabled for office applications (Exchange Teams Office 365 Apps)

.EXAMPLE
Test-MtCisSafeLink

Returns true safe links are enabled

.LINK
https://maester.dev/docs/commands/Test-MtCisSafeLink
#>
function Test-MtCisSafeLink {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }
    elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }
    elseif ($null -eq (Get-MtLicenseInformation -Product Mdo)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }

    Write-Verbose "Getting Safe Links Policy..."
    $policy = Get-MtExo -Request SafeLinksPolicy

    $safeLinkCheckList = @()

    #EnableSafeLinksForEmail
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "EnableSafeLinksForEmail"
        "Value"     = "True"
    }

    #EnableSafeLinksForTeams
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "EnableSafeLinksForTeams"
        "Value"     = "True"
    }

    #EnableSafeLinksForOffice
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "EnableSafeLinksForOffice"
        "Value"     = "True"
    }

    #TrackClicks
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "TrackClicks"
        "Value"     = "True"
    }

    #AllowClickThrough
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "AllowClickThrough"
        "Value"     = "False"
    }

    #ScanUrls
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "ScanUrls"
        "Value"     = "True"
    }

    #EnableForInternalSenders
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "EnableForInternalSenders"
        "Value"     = "True"
    }

    #DeliverMessageAfterScan
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "DeliverMessageAfterScan"
        "Value"     = "True"
    }

    #DisableUrlRewrite
    $safeLinkCheckList += [pscustomobject] @{
        "CheckName" = "DisableUrlRewrite"
        "Value"     = "True"
    }

    Write-Verbose "Executing checks"
    $failedCheckList = @()
    foreach ($check in $safeLinkCheckList) {

        $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }

        if ($checkResult) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += $check.CheckName
        }

    }

    $testResult = ($failedCheckList | Measure-Object).Count -eq 0

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has the recommended safelink settings configured ($portalLink).`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant does not have the recommended safelink settings configured ($portalLink).`n`n%TestResult%"
    }


    $resultMd = "| Check Name | Result |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $safeLinkCheckList) {
        $itemResult = "❌ Fail"
        if ($item.CheckName -notin $failedCheckList) {
            $itemResult = "✅ Pass"
        }
        $resultMd += "| $($item.CheckName) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}