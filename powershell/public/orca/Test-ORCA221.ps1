<#
.DESCRIPTION
    Mailbox intelligence is enabled in anti-phishing policies

.EXAMPLE
    Test-ORCA221

.LINK
    https://maester.dev/docs/commands/Test-ORCA221
#>

# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

function Test-ORCA221{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-ORCA221"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = $null
    }

    $Collection = Get-ORCACollection
    $obj = New-Object -TypeName ORCA221
    $obj.Run($Collection)
    $testResult = ($obj.Completed -and $obj.Result -eq "Pass")

    $resultMarkdown = "Microsoft Defender for Office 365 Policies - Mailbox Intelligence Enabled - `n`n"
    if($testResult){
        $resultMarkdown += "Well done. Mailbox intelligence is enabled in anti-phishing policies"
    }else{
        $resultMarkdown += "Your tenant did not pass. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $testResult
}
