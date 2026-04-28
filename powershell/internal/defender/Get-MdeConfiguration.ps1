function Get-MdeConfiguration {
    <#
    .SYNOPSIS
        Gets information about your organization's Defender-protected devices and their policies

    .DESCRIPTION
        Retrieves device inventory, configuration policies, and compliance information
        from Microsoft Graph API for use in MDE tests.

    .PARAMETER DisableCache
        Bypasses the Graph API response cache and fetches fresh data

    .EXAMPLE
        Get-MdeConfiguration

        Gets current MDE device and policy information.

    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch]$DisableCache
    )

    Write-Verbose "Getting managed devices from Microsoft Graph"
    $deviceParams = @{
        RelativeUri  = 'deviceManagement/managedDevices'
        ApiVersion   = 'v1.0'
        Select       = 'id,deviceName,operatingSystem,complianceState,managementAgent,azureADDeviceId,lastSyncDateTime'
        DisableCache = $DisableCache
    }
    $managedDevices = Invoke-MtGraphRequest @deviceParams

    if ($managedDevices) {
        foreach ($device in $managedDevices) {
            if ($device.lastSyncDateTime) {
                try {
                    $parsedDate = [DateTime]::Parse($device.lastSyncDateTime)
                    $device.lastSyncDateTime = $parsedDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                } catch {
                    Write-Verbose "Could not parse date for device $($device.deviceName): $($device.lastSyncDateTime)"
                }
            }
        }
    }

    Write-Verbose "Getting device configuration policies"
    $configParams = @{
        RelativeUri  = 'deviceManagement/configurationPolicies'
        ApiVersion   = 'beta'
        DisableCache = $DisableCache
    }
    $configPolicies = Invoke-MtGraphRequest @configParams

    Write-Verbose "Getting device compliance policies"
    $complianceParams = @{
        RelativeUri  = 'deviceManagement/deviceCompliancePolicies'
        ApiVersion   = 'v1.0'
        DisableCache = $DisableCache
    }
    $compliancePolicies = Invoke-MtGraphRequest @complianceParams

    Write-Verbose "Getting security baselines"
    $baselinesParams = @{
        RelativeUri  = 'deviceManagement/templates'
        ApiVersion   = 'beta'
        Filter       = "isof('microsoft.graph.securityBaselineTemplate')"
        DisableCache = $DisableCache
    }
    $securityBaselines = Invoke-MtGraphRequest @baselinesParams

    return @{
        ManagedDevices        = $managedDevices
        ConfigurationPolicies = $configPolicies
        CompliancePolicies    = $compliancePolicies
        SecurityBaselines     = $securityBaselines
        Timestamp             = Get-Date
    }
}
