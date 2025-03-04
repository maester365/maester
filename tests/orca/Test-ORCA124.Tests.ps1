# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA124", "EXO", "Security", "All" {
    It "ORCA124: Safe attachments unknown malware response set to block messages." {
        $result = Test-ORCA124

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe attachments unknown malware response set to block messages."
        }
    }
}
