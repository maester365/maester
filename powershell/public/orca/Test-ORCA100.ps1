<#
.DESCRIPTION
    Bulk Complaint Level threshold is between 4 and 6

.EXAMPLE
    Test-ORCA100

.LINK
    https://maester.dev/docs/commands/Test-ORCA100
#>

# Generated on 01/18/2025 19:34:46 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA100{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA100"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA100
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Anti-Spam Policies - Bulk Complaint Level - ORCA-100`n`n"
    if($testResult){
        $resultMarkdown += "Well done. Bulk Complaint Level threshold is between 4 and 6"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
