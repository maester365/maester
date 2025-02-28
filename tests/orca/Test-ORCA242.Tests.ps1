# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA242", "EXO", "Security", "All" {
    It "ORCA242: Protection Alerts" {
        $result = Test-ORCA242

        if($null -ne $result) {
            $result | Should -Be $true -Because "Important protection alerts responsible for AIR activities are enabled"
        }
    }
}
