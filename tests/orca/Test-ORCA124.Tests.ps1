# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA124", "EXO", "Security", "All" {
    It "ORCA124: Safe attachments unknown malware response" {
        $result = Test-ORCA124

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe attachments unknown malware response set to block messages"
        }
    }
}
