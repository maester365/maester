# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA116", "EXO", "Security", "All" {
    It "ORCA116: Mailbox intelligence based impersonation protection action set to move message to junk mail folder." {
        $result = Test-ORCA116

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection action set to move message to junk mail folder."
        }
    }
}
