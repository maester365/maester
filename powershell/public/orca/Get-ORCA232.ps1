# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

function Get-ORCA232{
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
    $obj = New-Object -TypeName ORCA232
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Malware Filter Policy - Malware Filter Policy Policy Rules - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Each domain has a malware filter policy applied to it, or the default policy is being used"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
