function Test-ORCA224Compliance {
    <#
    .SYNOPSIS
    Similar Users Safety Tips is enabled.

    .DESCRIPTION
    Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-ORCA224Compliance
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
    Write-Verbose "Test-ORCA224"

    if(($__MtSession.OrcaCache.Keys|Measure-Object).Count -eq 0){
        Write-Verbose "OrcaCache not set, Get-ORCACollection"
        $__MtSession.OrcaCache = Get-ORCACollection -SCC:$SCC # Specify SCC to include tests in Security & Compliance
    }
    $Collection = $__MtSession.OrcaCache
    $obj = New-Object -TypeName ORCA224
    try { # Handle "SkipInReport" which has a continue statement that makes this function exit unexpectedly
        $obj.Run($Collection)
    } catch {
        Write-OrcaError -TestId "ORCA224" -ErrorRecord $_ -AdditionalContext "Running ORCA224 test"
        throw
    } finally {
        if($obj.SkipInReport) {
        }
    }

    if($obj.CheckFailed) {
        return $null
    }elseif(-not $obj.Completed) {
        return $null
    }elseif($obj.SCC -and -not $SCC) {
        return = $null
    }

    $testResult = ($obj.ResultStandard -eq "Pass" -or $obj.ResultStandard -eq "Informational")

    if($testResult){
        $resultMarkdown += "Well done! Similar Users Safety Tips is enabled.`n`n%ResultDetail%"
    }else{
        $resultMarkdown += "The configured settings are not set as recommended.`n`n%ResultDetail%"
    }

    # Return early if we don't need to expand the results
    if (!$obj.ExpandResults) {
        return $testResult
    }

    $passResult = "`u{2705} Pass"
    $failResult = "`u{274C} Fail"
    $skipResult = "`u{1F5C4} Skip"
    $showObject = ""+$obj.CheckType -eq "ObjectPropertyValue"

    $resultDetail = "`n`n"
    if ($showObject) { $resultDetail += "|$($obj.ObjectType)" }
    $resultDetail += "|$($obj.ItemName)|$($obj.DataType)|Result|`n"

    if ($showObject) { $resultDetail += "|-" }
    $resultDetail += "|-|-|-|`n"

    ForEach ($result in $obj.Config) {
        If ($result.ResultStandard -eq "Pass") {
            $objResult = $passResult
        } ElseIf($result.ResultStandard -eq "Informational") {
            $objResult = $skipResult
        } Else {
            $objResult = $failResult
        }
        If ($showObject) { $resultDetail += "|$($result.Object)" }
        $resultDetail += "|$($result.ConfigItem)|$($result.ConfigData)|$objResult|`n"
    }
    $resultMarkdown = $resultMarkdown -replace "%ResultDetail%", $resultDetail


    return $testResult

}
