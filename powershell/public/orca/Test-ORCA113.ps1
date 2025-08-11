<#
.SYNOPSIS
    AllowClickThrough is disabled in Safe Links policies.

.DESCRIPTION
    Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

.EXAMPLE
    Test-ORCA113

    Returns true or false

.LINK
    https://maester.dev/docs/commands/Test-ORCA113
#>
function Test-ORCA113{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA113"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }
    if(Test-MtConnection SecurityCompliance){
        $SCC = $true
    } else {
        $SCC = $false
    }

    if(($__MtSession.OrcaCache.Keys|Measure-Object).Count -eq 0){
        Write-Verbose "OrcaCache not set, Get-ORCACollection"
        $__MtSession.OrcaCache = Get-ORCACollection -SCC:$SCC # Specify SCC to include tests in Security & Compliance
    }
    $Collection = $__MtSession.OrcaCache
    $obj = New-Object -TypeName ORCA113
    try { # Handle "SkipInReport" which has a continue statement that makes this function exit unexpectedly
        $obj.Run($Collection)
    } catch {
        Write-OrcaError -TestId "ORCA113" -ErrorRecord $_ -AdditionalContext "Running ORCA113 test"
        throw
    } finally {
        if($obj.SkipInReport) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'The statement "SkipInReport" was specified by ORCA.'
        }
    }

    if($obj.CheckFailed) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason $obj.CheckFailureReason
        return $null
    }elseif(-not $obj.Completed) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Possibly missing license for specific feature.'
        return $null
    }elseif($obj.SCC -and -not $SCC) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $testResult = ($obj.ResultStandard -eq "Pass" -or $obj.ResultStandard -eq "Informational")

    if($testResult){
        $resultMarkdown += "Well done! AllowClickThrough is disabled in Safe Links policies.`n`n%ResultDetail%"
    }else{
        $resultMarkdown += "The configured settings are not set as recommended.`n`n%ResultDetail%"
    }

    # Return early if we don't need to expand the results
    if (!$obj.ExpandResults) {
        Add-MtTestResultDetail -Result $resultMarkdown.TrimEnd("%ResultDetail%")
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

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
