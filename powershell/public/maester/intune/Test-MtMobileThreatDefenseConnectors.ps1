<#
.SYNOPSIS
    Check the Intune Mobile Threat Defense Connectors.
.DESCRIPTION
    This command checks the Mobile Threat Defense Connectors configured in Microsoft Intune to determine their status and connectivity.

.EXAMPLE
    Test-MtMobileThreatDefenseConnectors

    Returns true if all Mobile Threat Defense Connectors are enabled and have recent heartbeats, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtMobileThreatDefenseConnectors
#>
function Test-MtMobileThreatDefenseConnectors {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Multiple MTD connectors can exist.')]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Mobile Threat Defense Connectors status...'
        $mobileThreatDefenseConnectors = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/mobileThreatDefenseConnectors' -ApiVersion beta)

        $testResultMarkdown = "Mobile Threat Defense Connector Status:`n"
        $testResultMarkdown += "| Name | LastHeartbeatDateTime | PartnerState |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"

        $connectorStatus = foreach ($connector in $mobileThreatDefenseConnectors) {

            Write-Verbose ('Found Mobile Threat Defense Connector: {0}' -f $connector.id)

            if ($connector.id -eq 'fc780465-2017-40d4-a0c5-307022471b92' ) {
                Write-Verbose 'This is the Microsoft Defender for Endpoint Connector.'
                $testResultMarkdown += "| Microsoft Defender for Endpoint | $($connector.lastHeartbeatDateTime) | $($connector.partnerState) |`n"
            }else{
                $testResultMarkdown += "| $($connector.id) | $($connector.lastHeartbeatDateTime) | $($connector.partnerState) |`n"
            }

            $isConnected = $connector.partnerState -eq 'enabled'
            $syncIsRecent = [System.Math]::Floor(((Get-Date) - [datetime]$connector.lastHeartbeatDateTime).TotalDays) -eq 0
            Write-Output ($isConnected -and $syncIsRecent)
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $connectorStatus -notcontains $false

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
