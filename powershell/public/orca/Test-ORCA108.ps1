<#
.DESCRIPTION
    DKIM signing is set up for all your custom domains

.EXAMPLE
    Test-ORCA108

.LINK
    https://maester.dev/docs/commands/Test-ORCA108
#>

# Generated on 01/18/2025 19:34:46 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA108{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA108"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA108
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "DKIM - Signing Configuration - 108`n`n"
    if($testResult){
        $resultMarkdown += "Well done. DKIM signing is set up for all your custom domains"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
