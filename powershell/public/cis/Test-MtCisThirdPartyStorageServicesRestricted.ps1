<#
.SYNOPSIS
    Checks if users are restricted to store and share files in third-party storage services in Microsoft 365 on the web.

.DESCRIPTION
    Users should be restricted to store and share files in third-party storage services in Microsoft 365 on the web.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisThirdPartyStorageServicesRestricted

    Returns true if users are restricted to store and share files in third-party storage services in Microsoft 365 on the web.

.LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyStorageServicesRestricted
#>
function Test-MtCisThirdPartyStorageServicesRestricted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $ServicePrincipal = Invoke-MtGraphRequest -RelativeUri "servicePrincipals" -Filter "appId eq 'c1f33bc0-bdb4-4248-ba9b-096807ddb43e'" -DisableCache

        Write-Verbose 'Executing checks'
        if ($ServicePrincipal) {
            if ($ServicePrincipal.accountEnabled) {
                $testResult = $false
            } else {
                $testResult = $true
            }
        } else {
            $testResult = $false
        }

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($testResult) {
            $ThirdPartyStorageResult = '✅ Pass'
        } else {
            $ThirdPartyStorageResult = '❌ Fail'
        }

        $resultMd += "| Let users open files stored in third-party storage services in Microsoft 365 on the web | $ThirdPartyStorageResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}