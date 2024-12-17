# Generated on 10/25/2024 18:35:18 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA235", "EXO", "Security", "All" {
    It "ORCA235: SPF Records" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA235
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "SPF - SPF Records - 235`n`n"
            if($result){
                $resultMarkdown += "Well done. SPF records is set up for all your custom domains"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "SPF records is set up for all your custom domains"
        }
    }
}
