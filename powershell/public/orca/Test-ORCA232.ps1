<#
.DESCRIPTION
    Each domain has a malware filter policy applied to it, or the default policy is being used

.EXAMPLE
    Test-ORCA232

.LINK
    https://maester.dev/docs/commands/Test-ORCA232
#>

# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA232{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA232"
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
