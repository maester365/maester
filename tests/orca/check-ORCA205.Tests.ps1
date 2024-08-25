# Generated on 08/24/2024 20:37:39 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA205", "EXO", "Security", "All" {
    It "ORCA205: Common Attachment Type Filter" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA205
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Malware Filter Policy - Common Attachment Type Filter - `n`n"
            if($result){
                $resultMarkdown += "Well done. Common attachment type filter is enabled"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Common attachment type filter is enabled"
        }
    }
}
