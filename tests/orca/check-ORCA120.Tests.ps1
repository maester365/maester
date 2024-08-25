# Generated on 08/24/2024 20:37:39 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA120", "EXO", "Security", "All" {
    It "ORCA120: Zero Hour Autopurge Enabled for Spam" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA120
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Zero Hour Autopurge - Zero Hour Autopurge Enabled for Spam - 120-spam`n`n"
            if($result){
                $resultMarkdown += "Well done. Zero Hour Autopurge is Enabled"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge is Enabled"
        }
    }
}
