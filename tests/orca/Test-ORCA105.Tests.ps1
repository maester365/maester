# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.105", "EXO", "Security", "All" {
    It "ORCA.105: Safe Links Synchronous URL detonation is enabled." {
        $result = Test-ORCA105

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links Synchronous URL detonation is enabled."
        }
    }
}
