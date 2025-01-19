# Generated on 01/19/2025 05:57:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA189", "EXO", "Security", "All" {
    It "ORCA189: Safe Attachments Allow listing" {
        $result = Test-ORCA189

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is not bypassed"
        }
    }
}
