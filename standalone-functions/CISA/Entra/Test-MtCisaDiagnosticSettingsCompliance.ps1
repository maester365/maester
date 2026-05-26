function Test-MtCisaDiagnosticSettingsCompliance {
    <#
    .SYNOPSIS
    Checks for configuration of Entra diagnostic settings

    .DESCRIPTION
    Security logs SHALL be sent to the agency's security operations center for monitoring.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaDiagnosticSettingsCompliance
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

    if($EntraIDPlan -eq "Free"){
        return $null
    }

    $cisaLogs = @(
        "AuditLogs",
        "SignInLogs",
        "RiskyUsers",
        "UserRiskEvents",
        "NonInteractiveUserSignInLogs",
        "ServicePrincipalSignInLogs",
        "ADFSSignInLogs",
        "RiskyServicePrincipals",
        "ServicePrincipalRiskEvents",
        "EnrichedOffice365AuditLogs",
        "MicrosoftGraphActivityLogs",
        "ManagedIdentitySignInLogs"
    )

    $logs = Invoke-AzRestMethod -Method GET -Path "/providers/microsoft.aadiam/diagnosticSettingsCategories?api-version=2017-04-01-preview"
    $logs = ($logs.Content|ConvertFrom-Json).value
    $logs = ($logs | Where-Object { `
        $_.properties.categoryType -eq "Logs"
    }).name

    $configs = @()

    $settings = Invoke-AzRestMethod -Method GET -Path "/providers/microsoft.aadiam/diagnosticSettings?api-version=2017-04-01-preview"
    if ($settings.StatusCode -ne '200') {
        Write-Verbose "Could not retrieve diagnostic settings. Status code: $($settings.StatusCode) Message: $($settings.Content)"
        return $null
    }
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

    $testResult = ($unsetLogs | Where-Object { `
        $_ -in $cisaLogs
    } | Measure-Object).Count -eq 0

    $link = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DiagnosticSettingsMenuBlade/~/General"
    $resultFail = "❌ Fail"
    $resultPass = "✅ Pass"
    $resultOptional = "❔ Optional"
    $result = "| Log Name | Result |`n"
    $result += "| --- | --- |`n"

    foreach ($item in ($array | Sort-Object Log)) {
        if($item.Enabled){
        }elseif($item.Log -notin $cisaLogs){
        }
    }


    return $testResult

}
