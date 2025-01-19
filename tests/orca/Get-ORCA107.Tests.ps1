# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA107", "EXO", "Security", "All" {
    It "ORCA107: End-user Spam notifications" {
        $result = Get-ORCA107

        if($null -ne $result) {
            $result | Should -Be $true -Because "End-user spam notification is enabled"
        }
    }
}
