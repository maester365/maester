# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.240", "EXO", "Security", "All" {
    It "ORCA.240: Outlook is configured to display external tags for external emails." {
        $result = Test-ORCA240

        if($null -ne $result) {
            $result | Should -Be $true -Because "Outlook is configured to display external tags for external emails."
        }
    }
}
