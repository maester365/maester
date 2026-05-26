function Test-MtIntuneDiagnosticSettingsCompliance {
    <#
    .SYNOPSIS
    Check the Intune Diagnostic Settings for Audit Logs.

    .DESCRIPTION
    Enumerate all diagnostic settings for Intune and check if Audit Logs are being sent to a destination (Log Analytics, Storage Account, Event Hub).
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtIntuneDiagnosticSettingsCompliance
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
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation


    try {
        Write-Verbose 'Retrieving Intune Diagnostic Settings status...'
        $diagnosticSettingsRequest = Invoke-AzRestMethod -Method GET -Path "/providers/microsoft.intune/diagnosticSettings?api-version=2017-04-01-preview"

        # check whether the user has permissions to read diagnostic settings
        if ($diagnosticSettingsRequest.StatusCode -ne '200') {
            if ($diagnosticSettingsRequest.StatusCode -in @('401', '403')) {
                throw [System.UnauthorizedAccessException]::new('No Azure RBAC permissions to read Intune diagnostic settings.')
            } else {
                throw [System.Exception]::new(("Failed to retrieve Intune diagnostic settings. HTTP status code: {0}" -f $diagnosticSettingsRequest.StatusCode))
            }
        }

        $diagnosticSettings = @($diagnosticSettingsRequest | Select-Object -ExpandProperty Content | ConvertFrom-Json | Select-Object -ExpandProperty value)
        if ($diagnosticSettings) {
            foreach ($entry in $diagnosticSettings) {
                # check if AuditLogs category is enabled for this diagnostic setting
                $auditLogs = $entry.properties.logs | Where-Object { $_.category -eq 'AuditLogs' -and $_.enabled -eq $true }
                # determine the target destination for the diagnostic setting
                $target = if ($entry.properties.storageAccountId) {
                    'Storage Account'
                } elseif ($entry.properties.workspaceId) {
                    'Log Analytics'
                } elseif ($entry.properties.eventHubAuthorizationRuleId) {
                    'Event Hub'
                } else {
                    'Unknown'
                }
                if ($auditLogs) {
                    Write-Verbose ('Diagnostic settings for AuditLogs found: {0}' -f $entry.name)
                } else {
                    Write-Verbose ('Diagnostic settings: {0} do not include AuditLogs' -f $entry.name)
                }
            }
        } else {
        }
        return [bool]($diagnosticSettings | Where-Object { $_.properties.logs | Where-Object { $_.category -eq 'AuditLogs' -and $_.enabled -eq $true } })
    } catch [System.UnauthorizedAccessException] {
        return $null
    } catch {
        return $null
    }

}
