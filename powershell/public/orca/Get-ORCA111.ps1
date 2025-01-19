# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

function Get-ORCA111{
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
    $obj = New-Object -TypeName ORCA111
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Unauthenticated Sender (tagging) - ORCA-111`n`n"
    if($testResult){
        $resultMarkdown += "Well done. Anti-phishing policy exists and EnableUnauthenticatedSender is true"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
