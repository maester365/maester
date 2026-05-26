function Test-MtCertificateConnectorsCompliance {
    <#
    .SYNOPSIS
    Check Intune Certificate Connectors Health and Version

    .DESCRIPTION
    All Intune Certificate Connectors should be healthy and running supported versions.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCertificateConnectorsCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    try {
        Write-Verbose 'Retrieving Intune Certificate Connectors status...'
        $certificateConnectors = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/ndesConnectors'

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
        return $healthStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
    } catch {
        return $null
    }

}
