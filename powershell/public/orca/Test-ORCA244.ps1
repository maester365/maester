<#
.DESCRIPTION
    Policies are configured to honor sending domains DMARC.

.EXAMPLE
    Test-ORCA244

.LINK
    https://maester.dev/docs/commands/Test-ORCA244
#>

# Generated on 01/18/2025 19:34:48 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA244{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA244"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA244
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Anti-Phishing Policy - Honor DMARC Policy - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Policies are configured to honor sending domains DMARC."
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
