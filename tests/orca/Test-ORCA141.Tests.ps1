# Generated on 03/04/2025 09:42:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA141", "EXO", "Security", "All" {
    It "ORCA141: Bulk action set to Move message to Junk Email Folder." {
        $result = Test-ORCA141

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk action set to Move message to Junk Email Folder."
        }
    }
}
