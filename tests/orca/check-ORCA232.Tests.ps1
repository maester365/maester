# Generated on 10/25/2024 18:13:50 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA232", "EXO", "Security", "All" {
    It "ORCA232: Malware Filter Policy Policy Rules" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA232
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Malware Filter Policy - Malware Filter Policy Policy Rules - `n`n"
            if($result){
                $resultMarkdown += "Well done. Each domain has a malware filter policy applied to it, or the default policy is being used"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a malware filter policy applied to it, or the default policy is being used"
        }
    }
}
