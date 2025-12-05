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

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Apple Automated Device Enrollment token status...'
        $expirationThresholdDays = 30
        $adeTokens = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/depOnboardingSettings' -ApiVersion beta

        if (($adeTokens | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Apple Automated Device Enrollment tokens found.')
        }

        Write-Verbose ('{0} Apple Automated Device Enrollment token(s) found.' -f $adeTokens.Count)
        $testResultMarkdown = "Intune Automated Device Enrollment Token Status:`n"
        $testResultMarkdown += "| Name | TokenExpirationDateTime | LastSuccessfulSyncDateTime | LastSyncErrorCode |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"

        $healthStatus = foreach ($token in $adeTokens) {
            $expiresInDays = [System.Math]::Ceiling(([datetime]$token.tokenExpirationDateTime - (Get-Date)).TotalDays)
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$token.lastSuccessfulSyncDateTime).TotalDays)
            $testResultMarkdown += "| $($token.tokenName) | $($token.tokenExpirationDateTime) | $($token.lastSuccessfulSyncDateTime) | $($token.lastSyncErrorCode) |`n"
            Write-Output $($expiresInDays -gt $expirationThresholdDays -and $lastSyncDiffDays -eq 0)
        }

        $testResultMarkdown += '```' + "`n"
        $testResultMarkdown += $adeTokens | ConvertTo-Json
        $testResultMarkdown += "`n"
        $testResultMarkdown += '```'

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $healthStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $_
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    }
}
