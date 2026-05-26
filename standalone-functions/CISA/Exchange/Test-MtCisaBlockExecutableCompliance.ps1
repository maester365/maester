function Test-MtCisaBlockExecutableCompliance {
    <#
    .SYNOPSIS
    Checks state of preset security policies

    .DESCRIPTION
    Emails SHALL be filtered by attachment file types
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaBlockExecutableCompliance
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

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $policies = Get-MalwareFilterPolicy

    $clickToRunExtensions = @(
        "cmd",
        "exe",
        "vbe"
    )

    $resultPolicies = @()
    foreach($policy in $policies){
        $p = [PSCustomObject]@{
            Identity              = $policy.Identity
            EnableFileFilter      = $policy.EnableFileFilter
            RecommendedPolicyType = $policy.RecommendedPolicyType
            clickToRunExtensions  = @()
        }
        foreach($extension in $clickToRunExtensions){
            if($extension -in $policy.FileTypes){
                $p.clickToRunExtensions += $extension
            }
        }
        $resultPolicies += $p
    }

    $fileFilter = $resultPolicies | Where-Object { `
        $_.EnableFileFilter -and `
        ($_.clickToRunExtensions|Measure-Object).Count -eq ($clickToRunExtensions|Measure-Object).Count
    }

    $standard = $resultPolicies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $resultPolicies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($fileFilter|Measure-Object).Count -ge 1)

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Policy | Status |`n"
    $result += "| --- | --- |`n"
    if ($standard) {
        $result += "| Standard | $passResult |`n"
    } else {
        $result += "| Standard | $failResult |`n"
    }
    if ($strict) {
        $result += "| Strict | $passResult |`n`n"
    } else {
        $result += "| Strict | $failResult |`n`n"
    }

    $result += "| Policy Name | File Filter Enabled | Extensions |`n"
    $result += "| --- | --- | --- |`n"
    foreach($item in $resultPolicies | Sort-Object -Property Identity){
        if($item.EnableFileFilter){
            $resultFilesList = ($item.clickToRunExtensions) -join ", "
            $result += "| $($item.Identity) | $($passResult) | $resultFilesList |`n"
        }else{
            $result += "| $($item.Identity) | $($failResult) |  |`n"
        }
    }


    return $testResult

}
