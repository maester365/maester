function Test-MtCisUserOwnedAppsRestricted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "OrgSettings-AppsAndServices.Read.All" -notin $scopes
    if($permissionMissing){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Missing Scope OrgSettings-AppsAndServices.Read.All"
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/appsAndServices/settings" -DisableCache

        Write-Verbose 'Executing checks'
        $CheckIsOfficeStoreEnabled = $settings | Where-Object { $_.isOfficeStoreEnabled -eq $false }
        $CheckIsAppAndServicesTrialEnabled = $settings | Where-Object { $_.isAppAndServicesTrialEnabled -eq $false }

        $testResult = (($CheckIsOfficeStoreEnabled | Measure-Object).Count -ge 1) -and (($CheckIsAppAndServicesTrialEnabled | Measure-Object).Count -ge 1)

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($CheckIsOfficeStoreEnabled) {
            $CheckIsOfficeStoreEnabledResult = '✅ Pass'
        } else {
            $CheckIsOfficeStoreEnabledResult = '❌ Fail'
        }

        if ($CheckIsAppAndServicesTrialEnabled) {
            $CheckIsAppAndServicesTrialEnabledResult = '✅ Pass'
        } else {
            $CheckIsAppAndServicesTrialEnabledResult = '❌ Fail'
        }

        $resultMd += "| Let users access the Office Store | $CheckIsOfficeStoreEnabledResult |`n"
        $resultMd += "| Let users start trials on behalf of your organization | $CheckIsAppAndServicesTrialEnabledResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}