# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA242", "EXO", "Security", "All" {
    It "ORCA242: Protection Alerts" {
        $result = Test-ORCA242

        if($null -ne $result) {
            $result | Should -Be $true -Because "Important protection alerts responsible for AIR activities are enabled"
        }
    }
}
