# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

function Get-ORCA226{
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
    $obj = New-Object -TypeName ORCA226
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Safe Links Policy Rules - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Each domain has a Safe Link policy applied to it"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
