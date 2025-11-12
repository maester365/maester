<#
.SYNOPSIS
    Check the validity of the Apple Automated Device Enrollment (ADE) token for Intune.
.DESCRIPTION
    The Apple Automated Device Enrollment (ADE) token is required to synchronize Apple devices with Microsoft Intune. This command checks if the ADE token is valid and not expired.

.EXAMPLE
    Test-MtAppleAutomatedDeviceEnrollmentToken

    Returns true if the ADE token is valid for more than 30 days, false if it is expired or expiring soon.

.LINK
    https://maester.dev/docs/commands/Test-MtAppleAutomatedDeviceEnrollmentToken
#>
function Test-MtAppleAutomatedDeviceEnrollmentToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Apple Automated Device Enrollment Token for Intune...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        $expirationThresholdDays = 30
        $automatedDeviceEnrollmentTokens = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/depOnboardingSettings' -ApiVersion beta)

        $testResultMarkdown = "Intune Automated Device Enrollment Token Status:`n"
        $testResultMarkdown += "| Name | TokenExpirationDateTime | LastSuccessfulSyncDateTime | LastSyncErrorCode |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"

        $healthStatus = foreach ($token in $automatedDeviceEnrollmentTokens) {
            $expiresInDays = [System.Math]::Ceiling(([datetime]$token.tokenExpirationDateTime - (Get-Date)).TotalDays)
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$token.lastSuccessfulSyncDateTime).TotalDays)
            $testResultMarkdown += "| $($token.tokenName) | $($token.tokenExpirationDateTime) | $($token.lastSuccessfulSyncDateTime) | $($token.lastSyncErrorCode) |`n"
            Write-Output $($expiresInDays -gt $expirationThresholdDays -and $lastSyncDiffDays -eq 0)
        }

        $testDescription = '```' + "`n"
        $testDescription += $automatedDeviceEnrollmentTokens | ConvertTo-Json
        $testDescription += "`n"
        $testDescription += '```'

        Add-MtTestResultDetail -Result $testResultMarkdown -Description $testDescription
        return $healthStatus -notcontains $false
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
