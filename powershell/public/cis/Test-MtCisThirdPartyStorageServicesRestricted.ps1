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
            $testResultMarkdown = "Well done. Your tenants settings matches CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenants settings not matches CIS recommendations`n`n%TestResult%"
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