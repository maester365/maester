# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA221", "EXO", "Security", "All" {
    It "ORCA221: Mailbox intelligence is enabled in anti-phishing policies." {
        $result = Test-ORCA221

        if($null -ne $result) {
            $result | Should -Be $true -Because "Mailbox intelligence is enabled in anti-phishing policies."
        }
    }
}
