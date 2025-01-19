<#
.DESCRIPTION
    Safe Documents is enabled for Office clients

.EXAMPLE
    Test-ORCA225

.LINK
    https://maester.dev/docs/commands/Test-ORCA225
#>

# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA225{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA225"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA225
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Safe Documents for Office clients - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Safe Documents is enabled for Office clients"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
