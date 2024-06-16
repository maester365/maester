<#
.SYNOPSIS
    Checks for configuration of Entra diagnostic settings

.DESCRIPTION

    Security logs SHALL be sent to the agency's security operations center for monitoring.

.EXAMPLE
    Test-MtCisaDiagnosticSettings

    Returns true if diagnostic settings for the appropriate logs are configured

#>

Function Test-MtCisaDiagnosticSettings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Diagnostic Settings is a specific term')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $logs = Invoke-AzRestMethod -Path "/providers/microsoft.aadiam/diagnosticSettingsCategories?api-version=2017-04-01-preview"
    $logs = ($logs.Content|ConvertFrom-Json).value
    $logs = ($logs | Where-Object { `
        $_.properties.categoryType -eq "Logs"
    }).name

    $configs = @()

    $settings = Invoke-AzRestMethod -Path "/providers/microsoft.aadiam/diagnosticSettings?api-version=2017-04-01-preview"
    $settings = ($settings.Content|ConvertFrom-Json).value

    $settings | ForEach-Object { `
        $config = [PSCustomObject]@{
            name = $_.name
        }
        $_.properties.logs | ForEach-Object { `
            $config | Add-Member -MemberType NoteProperty -Name $_.category -Value $_.enabled
        }
        $configs += $config
    }

    foreach($log in $logs){
        if($configs.$log){
            $actual.$log = $true
        } else {
            $actual.$log = $false
        }
    }

    $unsetLogs = $actual.Keys | Where-Object { `
        $actual["$_"] -eq $false
    } | Sort-Object

    $testResult = $unsetLogs.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has diagnostic settings configured for all logs."
    } else {
        $testResultMarkdown = "Your tenant does not have diagnostic settings configured for all logs:`n`n%unsetLogs%"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType DiagnosticSettings

    return $testResult
}