# Generated on 08/24/2024 20:29:53 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA233", "EXO", "Security", "All" {
    It "ORCA233: Enhanced Filtering Configuration" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName check-ORCA233_1
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Connectors - Enhanced Filtering Configuration - 233_1`n`n"
            if($result){
                $resultMarkdown += "Well done. Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors"
        }
    }
}
