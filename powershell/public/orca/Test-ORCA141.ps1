<#
.DESCRIPTION
    Bulk action set to Move message to Junk Email Folder

.EXAMPLE
    Test-ORCA141

.LINK
    https://maester.dev/docs/commands/Test-ORCA141
#>

# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA141{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA141"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA141
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Anti-Spam Policies - Bulk Action - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Bulk action set to Move message to Junk Email Folder"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
