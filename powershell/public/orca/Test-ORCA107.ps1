<#
.DESCRIPTION
    End-user spam notification is enabled

.EXAMPLE
    Test-ORCA107

.LINK
    https://maester.dev/docs/commands/Test-ORCA107
#>

# Generated on 01/18/2025 19:34:46 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA107{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA107"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA107
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Quarantine Policies - End-user Spam notifications - ORCA-107`n`n"
    if($testResult){
        $resultMarkdown += "Well done. End-user spam notification is enabled"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
