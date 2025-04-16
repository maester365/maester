# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.116", "EXO", "Security", "All" {
    It "ORCA.116: Mailbox intelligence based impersonation protection action set to move message to junk mail folder." {
        $result = Test-ORCA116

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection action set to move message to junk mail folder."
        }
    }
}
