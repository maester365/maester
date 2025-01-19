# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA108", "EXO", "Security", "All" {
    It "ORCA108: Signing Configuration" {
        $result = Test-ORCA108

        if($null -ne $result) {
            $result | Should -Be $true -Because "DKIM signing is set up for all your custom domains"
        }
    }
}
