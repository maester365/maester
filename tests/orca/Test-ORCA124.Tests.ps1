# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.124", "EXO", "Security" {
    It "ORCA.124: Safe attachments unknown malware response set to block messages." {
        $result = Test-ORCA124

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe attachments unknown malware response set to block messages."
        }
    }
}
