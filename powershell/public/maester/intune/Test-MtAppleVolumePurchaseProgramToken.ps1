<#
.SYNOPSIS
    Check the validity of the Apple Volume Purchase Program (VPP) token for Intune.
.DESCRIPTION
    The Apple Volume Purchase Program (VPP) token is required to synchronize Apple store apps with Microsoft Intune. This command checks if the VPP token is valid and not expired.

.EXAMPLE
    Test-MtAppleVolumePurchaseProgramToken

    Returns true if the VPP token is valid for more than 30 days, false if it is expired or expiring soon.

.LINK
    https://maester.dev/docs/commands/Test-MtAppleVolumePurchaseProgramToken
#>
function Test-MtAppleVolumePurchaseProgramToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Apple Volume Purchase Program Token for Intune...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        $expirationThresholdDays = 30
        $vppTokens = @(Invoke-MtGraphRequest -RelativeUri 'deviceAppManagement/vppTokens' -ApiVersion beta)

        $testResultMarkdown = "Intune Volume Purchase Program Token Status:`n"
        $testResultMarkdown += "| Name | State | ExpirationDateTime | LastSyncDateTime |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"

        $healthStatus = foreach ($token in $vppTokens) {
            $expiresInDays = [System.Math]::Ceiling(([datetime]$token.expirationDateTime - (Get-Date)).TotalDays)
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$token.lastSyncDateTime).TotalDays)
            $testResultMarkdown += "| $($token.displayName) | $($token.state) | $($token.expirationDateTime) | $($token.lastSyncDateTime) |`n"
            Write-Output $($expiresInDays -gt $expirationThresholdDays -and $lastSyncDiffDays -eq 0)
        }

        $testDescription = '```' + "`n"
        $testDescription += $vppTokens | ConvertTo-Json
        $testDescription += "`n"
        $testDescription += '```'

        Add-MtTestResultDetail -Result $testResultMarkdown -Description $testDescription
        return $healthStatus -notcontains $false
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
