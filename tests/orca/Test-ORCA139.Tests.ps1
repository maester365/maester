# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA139", "EXO", "Security", "All" {
    It "ORCA139: Spam Action" {
        $result = Test-ORCA139

        if($null -ne $result) {
            $result | Should -Be $true -Because "Spam action set to move message to junk mail folder or quarantine"
        }
    }
}
