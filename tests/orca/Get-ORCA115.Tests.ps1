# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA115", "EXO", "Security", "All" {
    It "ORCA115: Mailbox Intelligence Protection" {
        $result = Get-ORCA115

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence based impersonation protection is enabled in anti-phishing policies"
        }
    }
}
