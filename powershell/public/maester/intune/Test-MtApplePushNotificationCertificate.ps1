<#
.SYNOPSIS
    Check the validity of the Apple Push Notification Service (APNS) Certificate for Intune.
.DESCRIPTION
    The Apple Push Notification Service (APNS) Certificate is required for managing Apple devices with Microsoft Intune. This command checks if the APNS certificate is valid and not expired.

.EXAMPLE
    Test-MtApplePushNotificationCertificate

    Returns true if the APNS certificate is valid for more than 30 days, false if it is expired or expiring soon.

.LINK
    https://maester.dev/docs/commands/Test-MtApplePushNotificationCertificate
#>
function Test-MtApplePushNotificationCertificate {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Apple Push Notification Certificate status...'
        $expirationThresholdDays = 30

        # if no APNS certificate is configured Graph API returns 404 error
        $pushNotificationCertificate = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/applePushNotificationCertificate' -ApiVersion beta -ErrorAction Stop

        $expiresInDays = [System.Math]::Ceiling(([datetime]$pushNotificationCertificate.expirationDateTime - (Get-Date)).TotalDays)
        $testResult = if ($expiresInDays -gt $expirationThresholdDays) {
            Write-Output "Apple Push Notification Certificate is valid for $($expiresInDays) more days.`n"
        } elseif ($expiresInDays -lt 0) {
            Write-Output "Apple Push Notification Certificate is expired since $([datetime]$pushNotificationCertificate.expirationDateTime) ($expiresInDays days ago).`n"
        } else {
            Write-Output "Apple Push Notification Certificate is expiring soon on $([datetime]$pushNotificationCertificate.expirationDateTime) ($expiresInDays days left).`n"
        }

        $testResult += '```' + "`n"
        $testResult += $pushNotificationCertificate | Select-Object -ExcludeProperty '@odata.context' | ConvertTo-Json
        $testResult += "`n"
        $testResult += '```'

        Add-MtTestResultDetail -Result $testResult
        return $expiresInDays -gt $expirationThresholdDays
    } catch {
        if ($_.Exception.Response.StatusCode -eq 'NotFound') {
            Write-Warning 'Apple Push Notification Certificate not found.'
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'No Apple Push Notification Certificate configured.'
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
