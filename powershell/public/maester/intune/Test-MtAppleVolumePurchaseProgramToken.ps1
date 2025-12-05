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

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Apple Volume Purchase Program token status...'
        $expirationThresholdDays = 30
        $vppTokens = Invoke-MtGraphRequest -RelativeUri 'deviceAppManagement/vppTokens' -ApiVersion beta

        if (($vppTokens | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Apple Volume Purchase Program tokens found.')
        }

        $testResultMarkdown = "Intune Volume Purchase Program Token Status:`n"
        $testResultMarkdown += "| Name | State | ExpirationDateTime | LastSyncDateTime |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"

        $healthStatus = foreach ($token in $vppTokens) {
            $expiresInDays = [System.Math]::Ceiling(([datetime]$token.expirationDateTime - (Get-Date)).TotalDays)
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$token.lastSyncDateTime).TotalDays)
            $testResultMarkdown += "| $($token.displayName) | $($token.state) | $($token.expirationDateTime) | $($token.lastSyncDateTime) |`n"
            Write-Output $($expiresInDays -gt $expirationThresholdDays -and $lastSyncDiffDays -le 1)
        }

        $testResultMarkdown += '```' + "`n"
        $testResultMarkdown += $vppTokens | ConvertTo-Json
        $testResultMarkdown += "`n"
        $testResultMarkdown += '```'

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $healthStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $_
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
