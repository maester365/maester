<#
.SYNOPSIS
    Check the health of the Android Enterprise connection for Intune.
.DESCRIPTION
    The Android Enterprise connection is required to synchronize Android enterprise apps and allow Android enrollment with Microsoft Intune. This command checks if the connection is valid and not expired.

.EXAMPLE
    Test-MtAndroidEnterpriseConnection

    Returns true if the Android Enterprise connection is healthy, false if it is expired or expiring soon.

.LINK
    https://maester.dev/docs/commands/Test-MtAndroidEnterpriseConnection
#>
function Test-MtAndroidEnterpriseConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Android Enterprise connection status...'

        $androidEnterpriseSettings = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/androidManagedStoreAccountEnterpriseSettings' -ApiVersion beta

        $testResultMarkdown = "Android Enterprise Account Status:`n"

        if ($androidEnterpriseSettings) {
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$androidEnterpriseSettings.lastAppSyncDateTime).TotalDays)
            $testResultMarkdown += "| Name | BindStatus | LastAppSyncDateTime |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"
            $testResultMarkdown += "| $($androidEnterpriseSettings.ownerUserPrincipalName) | $($androidEnterpriseSettings.bindStatus) | $($androidEnterpriseSettings.lastAppSyncDateTime) |`n"
            $testResultMarkdown += '```' + "`n"
            $testResultMarkdown += $androidEnterpriseSettings | Select-Object -ExcludeProperty '@odata.context', 'companyCodes' | ConvertTo-Json
            $testResultMarkdown += "`n"
            $testResultMarkdown += '```'
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $androidEnterpriseSettings.bindStatus -eq 'boundAndValidated' -and $androidEnterpriseSettings.lastAppSyncStatus -eq 'success' -and $lastSyncDiffDays -le 1
        }else{
            $testResultMarkdown += "No Android Enterprise account configured."
            Add-MtTestResultDetail -SkippedBecause Custom -Result $testResultMarkdown
        }

        return $false
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
