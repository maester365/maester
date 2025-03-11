# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA107", "EXO", "Security", "All" {
    It "ORCA107: End-user spam notification is enabled." {
        $result = Test-ORCA107

        if($null -ne $result) {
            $result | Should -Be $true -Because "End-user spam notification is enabled."
        }
    }
}
