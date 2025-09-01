# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.105", "EXO", "Security" {
    It "ORCA.105: Safe Links Synchronous URL detonation is enabled." {
        $result = Test-ORCA105

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links Synchronous URL detonation is enabled."
        }
    }
}
