# Generated on 10/25/2024 18:35:18 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA139", "EXO", "Security", "All" {
    It "ORCA139: Spam Action" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA139
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Anti-Spam Policies - Spam Action - `n`n"
            if($result){
                $resultMarkdown += "Well done. Spam action set to move message to junk mail folder or quarantine"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Spam action set to move message to junk mail folder or quarantine"
        }
    }
}
