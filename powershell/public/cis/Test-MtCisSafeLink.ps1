<#
.SYNOPSIS
    Checks if safe links for office applications are Enabled

.DESCRIPTION
    Safe links should be enabled for office applications (Exchange Teams Office 365 Apps)
    CIS Microsoft 365 Foundations Benchmark v5.0.0

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
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif ('P1' -notin (Get-MtLicenseInformation -Product MdoV2)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdoP1
        return $null
    }

    try {
        Write-Verbose 'Getting Safe Links Policy...'

        # Get the name of highest priority policy
        $priority0Policy = Get-MtExo -Request SafeLinksRule | Where-Object { $_.Priority -eq '0' }

        # Get policy highest priority policy
        $policy = Get-MtExo -Request SafeLinksPolicy | Where-Object { $_.Name -eq $priority0Policy }

        $safeLinkCheckList = @()

        #EnableSafeLinksForEmail
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeLinksForEmail'
            'Value'     = 'True'
        }

        #EnableSafeLinksForTeams
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeLinksForTeams'
            'Value'     = 'True'
        }

        #EnableSafeLinksForOffice
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeLinksForOffice'
            'Value'     = 'True'
        }

        #TrackClicks
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'TrackClicks'
            'Value'     = 'True'
        }

        #AllowClickThrough
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'AllowClickThrough'
            'Value'     = 'False'
        }

        #ScanUrls
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'ScanUrls'
            'Value'     = 'True'
        }

        #EnableForInternalSenders
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableForInternalSenders'
            'Value'     = 'True'
        }

        #DeliverMessageAfterScan
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'DeliverMessageAfterScan'
            'Value'     = 'True'
        }

        #DisableUrlRewrite
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'DisableUrlRewrite'
            'Value'     = 'True'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()
        foreach ($check in $safeLinkCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0

        $portalLink = 'https://security.microsoft.com/presetSecurityPolicies'

        if ($testResult) {
            $testResultMarkdown = 'Well done. Safe link policy' + $priority0Policy.Name + " (Priority 0 policy) matches CIS recommendations ($portalLink).`n`n%TestResult%"
        } else {
            $testResultMarkdown = 'Safe link policy' + $priority0Policy.Name + " (Priority 0 policy) does not match CIS recommendations ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Check Name | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $safeLinkCheckList) {
            $itemResult = '❌ Fail'
            if ($item.CheckName -notin $failedCheckList) {
                $itemResult = '✅ Pass'
            }
            $resultMd += "| $($item.CheckName) | $($itemResult) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
