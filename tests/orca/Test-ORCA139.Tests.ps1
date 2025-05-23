# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.139", "EXO", "Security", "All" {
    It "ORCA.139: Spam action set to move message to junk mail folder or quarantine." {
        $result = Test-ORCA139

        if($null -ne $result) {
            $result | Should -Be $true -Because "Spam action set to move message to junk mail folder or quarantine."
        }
    }
}
