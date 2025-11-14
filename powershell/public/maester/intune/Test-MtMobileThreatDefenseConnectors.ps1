<#
.SYNOPSIS
    Check the Intune Diagnostic Settings for Audit Logs.
.DESCRIPTION
    Enumarate all diagnostic settings for Intune and check if Audit Logs are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.EXAMPLE
    Test-MtMobileThreatDefenseConnectors

    Returns true if any Intune diagnostic settings include Audit Logs and are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.LINK
    https://maester.dev/docs/commands/Test-MtMobileThreatDefenseConnectors
#>
function Test-MtMobileThreatDefenseConnectors {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Apple Volume Purchase Program Token for Intune...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    if (-not (Test-MtConnection Azure)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    try {
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
