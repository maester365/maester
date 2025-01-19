<#
.DESCRIPTION
    Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO.

.EXAMPLE
    Test-ORCA243

.LINK
    https://maester.dev/docs/commands/Test-ORCA243
#>

# Generated on 01/18/2025 19:34:48 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA243{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA243"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA243
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Transport - Authenticated Receive Chain (ARC) - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO."
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
