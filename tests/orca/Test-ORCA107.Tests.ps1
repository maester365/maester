# Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA107", "EXO", "Security", "All" {
    It "ORCA107: End-user Spam notifications" {
        $result = Test-ORCA107

        if($null -ne $result) {
            $result | Should -Be $true -Because "End-user spam notification is enabled"
        }
    }
}
