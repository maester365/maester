# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA116", "EXO", "Security", "All" {
    It "ORCA116: Mailbox Intelligence Protection Action" {
        $result = Test-ORCA116

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection action set to move message to junk mail folder"
        }
    }
}
