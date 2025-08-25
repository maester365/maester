# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.107", "EXO", "Security" {
    It "ORCA.107: End-user spam notification is enabled." {
        $result = Test-ORCA107

        if($null -ne $result) {
            $result | Should -Be $true -Because "End-user spam notification is enabled."
        }
    }
}
