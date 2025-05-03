# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.189", "EXO", "Security", "All" {
    It "ORCA.189: Safe Attachments is not bypassed." {
        $result = Test-ORCA189

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is not bypassed."
        }
    }
}
