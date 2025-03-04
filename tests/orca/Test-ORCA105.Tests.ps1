# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA105", "EXO", "Security", "All" {
    It "ORCA105: Safe Links Synchronous URL detonation is enabled." {
        $result = Test-ORCA105

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links Synchronous URL detonation is enabled."
        }
    }
}
