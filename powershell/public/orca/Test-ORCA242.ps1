<#
.DESCRIPTION
    Important protection alerts responsible for AIR activities are enabled

.EXAMPLE
    Test-ORCA242

.LINK
    https://maester.dev/docs/commands/Test-ORCA242
#>

# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA242{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA242"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA242
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Alerts - Protection Alerts - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Important protection alerts responsible for AIR activities are enabled"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
