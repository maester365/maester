# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

function Get-ORCA235{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA235
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "SPF - SPF Records - 235`n`n"
    if($testResult){
        $resultMarkdown += "Well done. SPF records is set up for all your custom domains"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
