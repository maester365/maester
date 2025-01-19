# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA141", "EXO", "Security", "All" {
    It "ORCA141: Bulk Action" {
        $result = Test-ORCA141

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk action set to Move message to Junk Email Folder"
        }
    }
}
