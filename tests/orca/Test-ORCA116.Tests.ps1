# Generated on 03/04/2025 10:12:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA116", "EXO", "Security", "All" {
    It "ORCA116: Mailbox intelligence based impersonation protection action set to move message to junk mail folder." {
        $result = Test-ORCA116

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection action set to move message to junk mail folder."
        }
    }
}
