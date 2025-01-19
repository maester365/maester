# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA242", "EXO", "Security", "All" {
    It "ORCA242: Protection Alerts" {
        $result = Get-ORCA242

        if($null -ne $result) {
            $result | Should -Be $true -Because "Important protection alerts responsible for AIR activities are enabled"
        }
    }
}
