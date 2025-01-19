# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA189", "EXO", "Security", "All" {
    It "ORCA189: Safe Attachments Allow listing" {
        $result = Get-ORCA189

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Attachments is not bypassed"
        }
    }
}
