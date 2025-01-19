<#
.DESCRIPTION
    Safe Links Synchronous URL detonation is enabled

.EXAMPLE
    Test-ORCA105

.LINK
    https://maester.dev/docs/commands/Test-ORCA105
#>

# Generated on 01/18/2025 19:34:46 by .\build\orca\Update-OrcaTests.ps1

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

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA105
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Safe Links Synchronous URL detonation - ORCA-105`n`n"
    if($testResult){
        $resultMarkdown += "Well done. Safe Links Synchronous URL detonation is enabled"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
