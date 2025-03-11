# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA139", "EXO", "Security", "All" {
    It "ORCA139: Spam action set to move message to junk mail folder or quarantine." {
        $result = Test-ORCA139

        if($null -ne $result) {
            $result | Should -Be $true -Because "Spam action set to move message to junk mail folder or quarantine."
        }
    }
}
