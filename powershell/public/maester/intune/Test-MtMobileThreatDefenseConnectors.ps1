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

    # MTD Connector IDs and Names
    # Source: https://github.com/microsoft/Microsoft365DSC/blob/Dev/Modules/Microsoft365DSC/DSCResources/MSFT_IntuneDeviceConfigurationPolicyWindows10/MSFT_IntuneDeviceConfigurationPolicyWindows10.psm1
    $mtdConnectorInformation = @{
        'fc780465-2017-40d4-a0c5-307022471b92' = 'Microsoft Defender for Endpoint'
        '860d3ab4-8fd1-45f5-89cd-ecf51e4f92e5' = 'BETTER Mobile Security'
        'd3ddeae8-441f-4681-b80f-aef644f7195a' = 'Check Point Harmony Mobile'
        '8d0ed095-8191-4bd3-8a41-953b22d51ff7' = 'Pradeo'
        '1f58d6d2-02cc-4c80-b008-1bfe7396a10a' = 'Jamf Trust'
        '4873197-ffec-4dfc-9816-db65f34c7cb9'  = 'Trellix Mobile Security'
        'a447eca6-a986-4d3f-9838-5862bf50776c' = 'CylancePROTECT Mobile'
        '4928f0f6-2660-4f69-b4c5-5170ec921f7b' = 'Trend Micro'
        'bb13fe25-ce1f-45aa-b278-cabbc6b9072e' = 'SentinelOne'
        '29ee2d98-e795-475f-a0f8-0802dc3384a9' = 'CrowdStrike Falcon for Mobile'
        '870b252b-0ef0-4707-8847-50fc571472b3' = 'Sophos'
        '2c7790de-8b02-4814-85cf-e0c59380dee8' = 'Lookout for Work'
        '28fd67fd-b179-4629-a8b0-dad420b697c7' = 'Symantec Endpoint Protection'
        '08a8455c-48dd-45ff-ad82-7211355354f3' = 'Zimperium'
    }

    try {
        Write-Verbose 'Retrieving Mobile Threat Defense Connectors status...'
        $mobileThreatDefenseConnectors = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/mobileThreatDefenseConnectors' -ApiVersion beta

        if (($mobileThreatDefenseConnectors | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Mobile Threat Defense Connectors found.')
        }

        $testResultMarkdown = "Mobile Threat Defense Connector Status:`n"
        $testResultMarkdown += "| Name | LastHeartbeatDateTime | PartnerState |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"

        $connectorStatus = foreach ($connector in $mobileThreatDefenseConnectors) {

            if ($mtdConnectorInformation.ContainsKey($connector.id)) {
                Write-Verbose ('Found {0} Connector.' -f $mtdConnectorInformation[$connector.id])
                $testResultMarkdown += "| $($mtdConnectorInformation[$connector.id]) | $($connector.lastHeartbeatDateTime) | $($connector.partnerState) |`n"
            } else {
                Write-Verbose ('Found Unknown Third Party Mobile Threat Defense Connector: {0}' -f $connector.id)
                $testResultMarkdown += "| $($connector.id) | $($connector.lastHeartbeatDateTime) | $($connector.partnerState) |`n"
            }

            $isConnected = $connector.partnerState -eq 'enabled'
            $syncIsRecent = [System.Math]::Floor(((Get-Date) - [datetime]$connector.lastHeartbeatDateTime).TotalDays) -le 1
            Write-Output ($isConnected -and $syncIsRecent)
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $connectorStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $_
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
