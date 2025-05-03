# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.115", "EXO", "Security", "All" {
    It "ORCA.115: Mailbox intelligence based impersonation protection is enabled in anti-phishing policies." {
        $result = Test-ORCA115

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection is enabled in anti-phishing policies."
        }
    }
}
