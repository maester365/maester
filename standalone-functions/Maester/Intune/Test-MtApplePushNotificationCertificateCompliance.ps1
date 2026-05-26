function Test-MtApplePushNotificationCertificateCompliance {
    <#
    .SYNOPSIS
    Check the validity of the Apple Push Notification Service (APNS) Certificate for Intune.

    .DESCRIPTION
    The Apple Push Notification Service (APNS) Certificate is required for managing Apple devices with Microsoft Intune. This command checks if the APNS certificate is valid and not expired.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtApplePushNotificationCertificateCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose 'Retrieving Apple Push Notification Certificate status...'
        $expirationThresholdDays = 30

        # if no APNS certificate is configured Graph API returns 404 error
        $pushNotificationCertificate = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate' -ErrorAction Stop

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

        return $expiresInDays -gt $expirationThresholdDays
    } catch {
        if ($_.Exception.Response.StatusCode -eq 'NotFound') {
            Write-Warning 'Apple Push Notification Certificate not found.'
        } else {
        }
        return $null
    }

}
