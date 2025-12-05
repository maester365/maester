<#
.SYNOPSIS
    Check Intune Certificate Connectors Health and Version

.DESCRIPTION
    All Intune Certificate Connectors should be healthy and running supported versions.

.EXAMPLE
    Test-MtCertificateConnectors
    Returns true if all Intune Certificate Connectors are healthy and running supported versions, false if any connector is unhealthy.

.LINK
    https://maester.dev/docs/commands/Test-MtCertificateConnectors
#>
function Test-MtCertificateConnectors {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test refers to multiple settings.')]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }
    try {
        Write-Verbose 'Retrieving Intune Certificate Connectors status...'
        $certificateConnectors = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/ndesConnectors' -ApiVersion beta

        if (($certificateConnectors | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Intune Certificate Connectors found.')
        }

        # https://learn.microsoft.com/en-us/intune/intune-service/protect/certificate-connector-overview#lifecycle
        $minimumVersion = [System.Version]'6.2406.0.1001'

        $healthStatus = foreach ($connector in $certificateConnectors) {
            # Connector Health checks
            $isActive = $connector.state -eq 'active'
            $isSupportedVersion = [System.Version]$connector.connectorVersion -ge $minimumVersion
            $hasRecentlyConnected = ((Get-Date) - [DateTime]$connector.lastConnectionDateTime).TotalHours -le 1

            Write-Output $($isActive -and $isSupportedVersion -and $hasRecentlyConnected)
        }

        $testResultMarkdown = "Intune Certificate Connector Health Status:`n"
        $testResultMarkdown += "| Name | State | LastConnectionDateTime | Version |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"
        foreach ($connector in $certificateConnectors) {
            $testResultMarkdown += "| $($connector.displayName) | $($connector.state) | $($connector.lastConnectionDateTime) | $($connector.connectorVersion) |`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $healthStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $_
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
