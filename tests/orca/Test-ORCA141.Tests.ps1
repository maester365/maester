# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.141", "EXO", "Security", "All" {
    It "ORCA.141: Bulk action set to Move message to Junk Email Folder." {
        $result = Test-ORCA141

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk action set to Move message to Junk Email Folder."
        }
    }
}
