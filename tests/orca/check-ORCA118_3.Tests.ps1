# Generated on 08/24/2024 20:29:53 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA118", "EXO", "Security", "All" {
    It "ORCA118: Domain Allowlist" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName check-ORCA118_3
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Anti-Spam Policies - Domain Allowlist - ORCA-118-3`n`n"
            if($result){
                $resultMarkdown += "Well done. Your own domains are not being allow listed in an unsafe manner"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Your own domains are not being allow listed in an unsafe manner"
        }
    }
}
