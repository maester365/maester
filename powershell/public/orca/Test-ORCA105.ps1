<#
.SYNOPSIS
    Safe Links Synchronous URL detonation is enabled

.DESCRIPTION
    Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

.EXAMPLE
    Test-ORCA105

    Returns true or false

.LINK
    https://maester.dev/docs/commands/Test-ORCA105
#>
function Test-ORCA105{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA105"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    if(($__MtSession.OrcaCache.Keys|Measure-Object).Count -eq 0){
        Write-Verbose "OrcaCache not set, Get-ORCACollection"
        $__MtSession.OrcaCache = Get-ORCACollection
    }
    $Collection = $__MtSession.OrcaCache
    $obj = New-Object -TypeName ORCA105
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Safe Links Synchronous URL detonation - ORCA-105`n`n"
    if($testResult){
        $resultMarkdown += "Well done. Safe Links Synchronous URL detonation is enabled`n`n%ResultDetail%"
    }else{
        $resultMarkdown += "Your tenant did not pass. `n`n%ResultDetail%"
    }

    $passResult = "`u{2705} Pass"
    $failResult = "`u{274C} Fail"
    $skipResult = "`u{1F5C4}  Skip"
    $resultDetail = "| $($obj.ItemName) | $($obj.DataType) | Result |`n"
    $resultDetail += "| --- | --- | --- |`n"
    foreach($config in $obj.Config){
        switch($config.ResultStandard){
            "Pass" {$itemResult = $passResult}
            "Informational" {$itemResult = $skipResult}
            "None" {$itemResult = $skipResult}
            "Fail" {$itemResult = $failResult}
        }
        $resultDetail += "| $($config.ConfigItem) | $($config.ConfigData) | $itemResult |`n"
    }

    $resultMarkdown = $resultMarkdown -replace "%ResultDetail%", $resultDetail

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
