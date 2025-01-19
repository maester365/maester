# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

function Get-ORCA102{
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
    $obj = New-Object -TypeName ORCA102
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Anti-Spam Policies - Advanced Spam Filter (ASF) - ORCA-102`n`n"
    if($testResult){
        $resultMarkdown += "Well done. Advanced Spam filter options are turned off"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
