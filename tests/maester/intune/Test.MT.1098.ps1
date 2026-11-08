function Test-MtMobileThreatDefenseConnectors {
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
    [MaesterTest(
        Id = 'MT.1098',
        Title = 'Mobile Threat Defense Connectors should be healthy',
        Product = 'intune',
        RelatedProduct = 'defender',
        Feature = 'tenant-administration',
        Area = 'devices',
        ResourceType = 'Connector',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'nicolonsky',
        Contributor = ('Mynster9361', 'FiraSenax')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Multiple MTD connectors can exist.')]
    param()

    # MTD Connector IDs and Names
    # Source: https://github.com/microsoft/Microsoft365DSC/blob/Dev/Modules/Microsoft365DSC/DSCResources/MSFT_IntuneDeviceConfigurationPolicyWindows10/MSFT_IntuneDeviceConfigurationPolicyWindows10.psm1
    $mtdConnectorInformation = @{
        '2c7790de-8b02-4814-85cf-e0c59380dee8' = 'Lookout for Work'
        '28fd67fd-b179-4629-a8b0-dad420b697c7' = 'Symantec Endpoint Protection'
        'd3ddeae8-441f-4681-b80f-aef644f7195a' = 'Check Point Harmony Mobile'
        '08a8455c-48dd-45ff-ad82-7211355354f3' = 'Zimperium'
        '8d0ed095-8191-4bd3-8a41-953b22d51ff7' = 'Pradeo'
        '860d3ab4-8fd1-45f5-89cd-ecf51e4f92e5' = 'BETTER Mobile Security'
        '870b252b-0ef0-4707-8847-50fc571472b3' = 'Sophos'
        '1f58d6d2-02cc-4c80-b008-1bfe7396a10a' = 'Jamf Trust'
        '4873197-ffec-4dfc-9816-db65f34c7cb9'  = 'Trellix Mobile Security'
        'a447eca6-a986-4d3f-9838-5862bf50776c' = 'CylancePROTECT Mobile'
        '4928f0f6-2660-4f69-b4c5-5170ec921f7b' = 'Trend Micro'
        'bb13fe25-ce1f-45aa-b278-cabbc6b9072e' = 'SentinelOne'
        'c2b688fe-48c0-464b-a89c-67041aa8fcb2' = 'Windows Security Center'
        '29ee2d98-e795-475f-a0f8-0802dc3384a9' = 'CrowdStrike Falcon for Mobile'
        'fc780465-2017-40d4-a0c5-307022471b92' = 'Microsoft Defender for Endpoint'
        'fc06ff9b-e2f9-4221-9a68-465684ee8662' = 'iVerify'
    }

    try {
        Write-Verbose 'Retrieving Mobile Threat Defense Connectors status...'
        $mobileThreatDefenseConnectors = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/mobileThreatDefenseConnectors' -ApiVersion beta

        if (($mobileThreatDefenseConnectors | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Mobile Threat Defense Connectors found.')
        }

        $testResultMarkdown = "Mobile Threat Defense Connector Status:`n"
        $testResultMarkdown += "| Name | LastHeartbeatDateTime | PartnerState | Reason |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"

        $connectorStatus = foreach ($connector in $mobileThreatDefenseConnectors) {

            if ($mtdConnectorInformation.ContainsKey($connector.id)) {
                Write-Verbose ('Found {0} Connector.' -f $mtdConnectorInformation[$connector.id])
                $connectorName = $mtdConnectorInformation[$connector.id]
            } else {
                Write-Verbose ('Found Unknown Third Party Mobile Threat Defense Connector: {0}' -f $connector.id)
                $connectorName = $connector.id
            }

            $isConnected = $connector.partnerState -eq 'enabled'
            $reasons = @(switch ($connector.partnerState) {
                'enabled' { break }
                'notSetUp' { 'Setup is incomplete; device threat messages are blocked. Complete setup in Intune and with the partner, or remove an unused connector.' }
                'unavailable' { 'The connector is deprovisioned; device threat messages are blocked. Ask the MTD partner to provision it again.' }
                'available' { 'Setup is complete. Turn on a platform toggle to enable the connector.' }
                'unresponsive' { 'The connector is unresponsive. After its configured unresponsiveness threshold, Intune ignores its compliance state. Check the partner service and connectivity.' }
                'error' { 'The connector reported an error. Check the partner service for the error details.' }
                default { 'Unrecognized connector state. Review the connector in Intune and with the partner.' }
            })

            $heartbeat = if ($connector.lastHeartbeatDateTime) { [datetime]$connector.lastHeartbeatDateTime } else { [datetime]::MinValue }
            if ($heartbeat.Year -eq 1) {
                $heartbeatDisplay = 'Never received'
                $syncIsRecent = $false
                $reasons += 'No heartbeat has been received. Complete setup and verify that the partner can communicate with Intune.'
            } else {
                $heartbeatDisplay = [string]$connector.lastHeartbeatDateTime
                # Keep the existing window: at most one completed day since the heartbeat (less than 48 hours).
                $syncIsRecent = [System.Math]::Floor(((Get-Date) - $heartbeat).TotalDays) -le 1
                if (-not $syncIsRecent) {
                    $reasons += "Heartbeat is outside the test's existing window (less than 48 hours). Check the partner service and connectivity."
                }
            }

            if ($isConnected -and $syncIsRecent) {
                $reasons = @('Enabled with a recent heartbeat.')
            }

            $nameMarkdown = Get-MtSafeMarkdown -Text $connectorName
            $heartbeatMarkdown = Get-MtSafeMarkdown -Text $heartbeatDisplay
            $stateMarkdown = Get-MtSafeMarkdown -Text ([string]$connector.partnerState)
            $testResultMarkdown += "| $nameMarkdown | $heartbeatMarkdown | $stateMarkdown | $($reasons -join ' ') |`n"
            Write-Output ($isConnected -and $syncIsRecent)
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $connectorStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $_
    }
}
