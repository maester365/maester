# Generated on 08/24/2024 20:37:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA227", "EXO", "Security", "All" {
    It "ORCA227: Safe Attachments Policy Rules" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA227
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Microsoft Defender for Office 365 Policies - Safe Attachments Policy Rules - `n`n"
            if($result){
                $resultMarkdown += "Well done. Each domain has a Safe Attachments policy applied to it"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Safe Attachments policy applied to it"
        }
    }
}
