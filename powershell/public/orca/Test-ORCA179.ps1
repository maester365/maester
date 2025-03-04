<#
.SYNOPSIS
    Safe Links is enabled intra-organization.

.DESCRIPTION
    Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

.EXAMPLE
    Test-ORCA179

    Returns true or false

.LINK
    https://maester.dev/docs/commands/Test-ORCA179
#>
function Test-ORCA179{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA179"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    if(($__MtSession.OrcaCache.Keys|Measure-Object).Count -eq 0){
        Write-Verbose "OrcaCache not set, Get-ORCACollection"
        $__MtSession.OrcaCache = Get-ORCACollection -SCC:$true
    }
    $Collection = $__MtSession.OrcaCache
    $obj = New-Object -TypeName ORCA179
    try { # Handle "SkipInReport" which has a continue statement that makes this function exit unexpectedly
        $obj.Run($Collection)
    } catch {
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
    }

    $testResult = ($obj.ResultStandard -eq "Pass" -or $obj.ResultStandard -eq "Informational")

    if($testResult){
        $resultMarkdown += "Well done! Safe Links is enabled intra-organization.`n`n%ResultDetail%"
    }else{
        $resultMarkdown += "The configured settings are not set as recommended.`n`n%ResultDetail%"
    }

    $passResult = "`u{2705} Pass"
    $failResult = "`u{274C} Fail"
    $skipResult = "`u{1F5C4} Skip"
    if ($obj.ExpandResults) {
        $resultDetail += "`n`n$(If (-not [string]::IsNullOrEmpty($obj.Config[0].Object)) {"|$($obj.ObjectType)"})$(If (-not [string]::IsNullOrEmpty($obj.Config[0].ConfigItem)) {"|$($obj.ItemName)"})$(If (-not [string]::IsNullOrEmpty($obj.Config[0].ConfigData)) {"|$($obj.DataType)"})|Result|`n"
        $resultDetail += "$(If (-not [string]::IsNullOrEmpty($obj.Config[0].Object)) {"|-"})$(If (-not [string]::IsNullOrEmpty($obj.Config[0].ConfigItem)) {"|-"})$(If (-not [string]::IsNullOrEmpty($obj.Config[0].ConfigData)) {"|-"})|-|`n"
        ForEach ($result in $obj.Config) {
            If ($result.ResultStandard -eq "Pass") {
                $objResult = $passResult
            } ElseIf($result.ResultStandard -eq "Informational") {
                $objResult = $skipResult
            } Else {
                $objResult = $failResult
            }
            $resultDetail += "$(If (-not [string]::IsNullOrEmpty($result.Object)) {"|$($result.Object)"})$(If (-not [string]::IsNullOrEmpty($result.ConfigItem)) {"|$($result.ConfigItem)"})$(If (-not [string]::IsNullOrEmpty($result.ConfigData)) {"|$($result.ConfigData)"})|$objResult|`n"
        }
    }

    $resultMarkdown = $resultMarkdown -replace "%ResultDetail%", $resultDetail

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
