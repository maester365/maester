# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA221", "EXO", "Security", "All" {
    It "ORCA221: Mailbox Intelligence Enabled" {
        $result = Test-ORCA221

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence is enabled in anti-phishing policies"
        }
    }
}
