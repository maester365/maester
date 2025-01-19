<#
.DESCRIPTION
    Unusual Characters Safety Tips is enabled

.EXAMPLE
    Test-ORCA123

.LINK
    https://maester.dev/docs/commands/Test-ORCA123
#>

# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA123{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA123"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA123
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Unusual Characters Safety Tips - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Unusual Characters Safety Tips is enabled"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
