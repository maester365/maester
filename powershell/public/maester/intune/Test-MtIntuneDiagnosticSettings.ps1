<#
.SYNOPSIS
    Check the Intune Diagnostic Settings for Audit Logs.
.DESCRIPTION
    Enumerate all diagnostic settings for Intune and check if Audit Logs are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.EXAMPLE
    Test-MtIntuneDiagnosticSettings

    Returns true if any Intune diagnostic settings include Audit Logs and are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.LINK
    https://maester.dev/docs/commands/Test-MtIntuneDiagnosticSettings
#>
function Test-MtIntuneDiagnosticSettings {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Multiple diagnostic settings can exist.')]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    if (-not (Test-MtConnection Azure)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    try {
        Write-Verbose 'Retrieving Intune Diagnostic Settings status...'
        $diagnosticSettingsRequest = Invoke-AzRestMethod -Method GET -Path "/providers/microsoft.intune/diagnosticSettings?api-version=2017-04-01-preview"
        $diagnosticSettings = @($diagnosticSettingsRequest | Select-Object -ExpandProperty Content | ConvertFrom-Json | Select-Object -ExpandProperty value)
        $testResultMarkdown = ''
        if ($diagnosticSettings) {
            $testResultMarkdown += "Intune Diagnostic Settings:`n"
            $testResultMarkdown += "| Name | IncludesAuditLogs | Destination |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"
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
                $testResultMarkdown += "| $($entry.name) | {0} | $target |`n" -f (($entry.properties.logs | Where-Object { $_.enabled } | Select-Object -ExpandProperty category) -join ",")
            }
        } else {
            $testResultMarkdown += "No Intune Diagnostic Settings found."
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        return [bool]($diagnosticSettings | Where-Object { $_.properties.logs | Where-Object { $_.category -eq 'AuditLogs' -and $_.enabled -eq $true } })
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
