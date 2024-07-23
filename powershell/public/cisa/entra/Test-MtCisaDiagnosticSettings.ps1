﻿<#
.SYNOPSIS
    Checks for configuration of Entra diagnostic settings

.DESCRIPTION
    Security logs SHALL be sent to the agency's security operations center for monitoring.

.EXAMPLE
    Test-MtCisaDiagnosticSettings

    Returns true if diagnostic settings for the appropriate logs are configured

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDiagnosticSettings
#>
function Test-MtCisaDiagnosticSettings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Diagnostic Settings is a specific term')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Azure)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    $logs = Invoke-AzRestMethod -Method GET -Path "/providers/microsoft.aadiam/diagnosticSettingsCategories?api-version=2017-04-01-preview"
    $logs = ($logs.Content|ConvertFrom-Json).value
    $logs = ($logs | Where-Object { `
        $_.properties.categoryType -eq "Logs"
    }).name

    $configs = @()

    $settings = Invoke-AzRestMethod -Method GET -Path "/providers/microsoft.aadiam/diagnosticSettings?api-version=2017-04-01-preview"
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

    $actual = @{}
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

    $array = $actual.Keys | ForEach-Object { `
        [pscustomobject]@{
            Log = "$_"
            Enabled = $($actual[$_])
        }
    }

    $testResult = $unsetLogs.Count -eq 0

    $link = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DiagnosticSettingsMenuBlade/~/General"
    $resultFail = "❌ Fail"
    $resultPass = "✅ Pass"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [diagnostic settings]($link) configured for all logs."
    } else {
        $testResultMarkdown = "Your tenant does not have [diagnostic settings]($link) configured for all logs:`n`n%TestResult%"
    }

    $result = "| Log Name | Result |`n"
    $result += "| --- | --- |`n"

    foreach ($item in ($array | Sort-Object Log)) {
        $itemResult = $resultFail
        if($item.Enabled){
            $itemResult = $resultPass
        }
        $result += "| $($item.Log) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}