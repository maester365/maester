function Test-MtCisaExoAlertCompliance {
    <#
    .SYNOPSIS
    Checks state of alerts

    .DESCRIPTION
    Alerts SHALL be enabled.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaExoAlertCompliance
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
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    try {
        $sccSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.ComputerName -match 'compliance' -and $_.State -eq 'Opened' }
        if ($null -eq $sccSession) {
            Write-Verbose "Not connected to Security & Compliance Center"
            return $null
        }
    } catch {
        Write-Verbose "Security & Compliance connection check failed: $_"
        return $null
    }

    try {
        $sku = Get-MgSubscribedSku | Where-Object { $_.ServicePlans.ServicePlanName -match 'MDE_ATP|THREAT_INTELLIGENCE|ATP_ENTERPRISE' }
        if ($null -eq $sku) {
            Write-Verbose "Microsoft Defender for Office 365 P1 license not found"
            return $null
        }
    } catch {
        Write-Verbose "License check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $alerts = Get-ProtectionAlert

    $cisaAlerts = @{
        'be215649-fba8-4339-9ddd-05991a43b948' = 'Suspicious email sending patterns detected'
        '8bb9c6c8-dc12-40e1-5bb8-08da05b13393' = 'Suspicious connector activity'
        'bfd48f06-0865-41a6-85ff-adb746423ebf' = 'Suspicious Email Forwarding Activity'
        '37a4e852-e711-45ca-b0f4-b076bae3adfd' = 'Messages have been delayed'
        '5ed2d687-9bd3-49e7-9b56-b7dc0d9af5cb' = 'Tenant restricted from sending unprovisioned email'
        'a7032ff5-7eee-412b-805b-d1295c7e0932' = 'Tenant restricted from sending email'
    }

    $resultAlerts = $alerts | Where-Object { `
        $_.ExchangeObjectId -in $cisaAlerts.Keys -and `
        $_.NotificationEnabled
    }

    $testResult = ($resultAlerts.Count -eq $cisaAlerts.Count)

    $passResult = '✅ Pass'
    $failResult = '❌ Fail'
    $result = "| Alert Name | Alert Result |`n"
    $result += "| --- | --- |`n"
    foreach ($item in $cisaAlerts.GetEnumerator()) {
        if ($item.Key -in $resultAlerts.Guid) {
            $result += "| $($item.Value) | $passResult |`n"
        } else {
            $result += "| $($item.Value) | $failResult |`n"
        }
    }


    return $testResult

}
