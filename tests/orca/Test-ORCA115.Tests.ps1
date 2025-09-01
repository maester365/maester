# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.115", "EXO", "Security" {
    It "ORCA.115: Mailbox intelligence based impersonation protection is enabled in anti-phishing policies." {
        $result = Test-ORCA115

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection is enabled in anti-phishing policies."
        }
    }
}
