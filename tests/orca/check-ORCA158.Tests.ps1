# Generated on 10/25/2024 17:00:43 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA158", "EXO", "Security", "All" {
    It "ORCA158: Safe Attachments SharePoint and Teams" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            $result = $null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            $result = $null
        }else{
            $Collection = Get-ORCACollection
            $obj = New-Object -TypeName ORCA158
            $obj.Run($Collection)
            $result = ($obj.Completed -and $obj.Result -eq "Pass")

            $resultMarkdown = "Microsoft Defender for Office 365 Policies - Safe Attachments SharePoint and Teams - `n`n"
            if($result){
                $resultMarkdown += "Well done. Safe Attachments is enabled for SharePoint and Teams"
            }else{
                $resultMarkdown += "Your tenant did not pass. "
            }

            Add-MtTestResultDetail -Result $resultMarkdown
        }

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is enabled for SharePoint and Teams"
        }
    }
}
