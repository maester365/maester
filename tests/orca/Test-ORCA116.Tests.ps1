# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.116", "EXO", "Security" {
    It "ORCA.116: Mailbox intelligence based impersonation protection action set to move message to junk mail folder." {
        $result = Test-ORCA116

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection action set to move message to junk mail folder."
        }
    }
}
