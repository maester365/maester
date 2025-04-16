# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.107", "EXO", "Security", "All" {
    It "ORCA.107: End-user spam notification is enabled." {
        $result = Test-ORCA107

        if($null -ne $result) {
            $result | Should -Be $true -Because "End-user spam notification is enabled."
        }
    }
}
