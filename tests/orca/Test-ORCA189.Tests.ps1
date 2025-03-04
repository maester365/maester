# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA189", "EXO", "Security", "All" {
    It "ORCA189: Safe Attachments is not bypassed." {
        $result = Test-ORCA189

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is not bypassed."
        }
    }
}
