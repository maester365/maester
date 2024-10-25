# Generated on 10/25/2024 16:51:12 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA115", "EXO", "Security", "All" {
    It "ORCA115: Mailbox Intelligence Protection" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA115
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Microsoft Defender for Office 365 Policies - Mailbox Intelligence Protection - `n`n"
            if($result){
                $resultMarkdown += "Well done. Mailbox intelligence based impersonation protection is enabled in anti-phishing policies"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection is enabled in anti-phishing policies"
        }
    }
}
