# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.221", "EXO", "Security", "All" {
    It "ORCA.221: Mailbox intelligence is enabled in anti-phishing policies." {
        $result = Test-ORCA221

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence is enabled in anti-phishing policies."
        }
    }
}
