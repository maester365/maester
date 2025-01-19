<#
.DESCRIPTION
    High Confidence Phish action set to Quarantine message

.EXAMPLE
    Test-ORCA104

.LINK
    https://maester.dev/docs/commands/Test-ORCA104
#>

# Generated on 01/18/2025 19:34:46 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA104{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA104"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA104
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Anti-Spam Policies - High Confidence Phish Action - ORCA-104`n`n"
    if($testResult){
        $resultMarkdown += "Well done. High Confidence Phish action set to Quarantine message"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
