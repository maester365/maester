# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.141", "EXO", "Security" {
    It "ORCA.141: Bulk action set to Move message to Junk Email Folder." {
        $result = Test-ORCA141

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk action set to Move message to Junk Email Folder."
        }
    }
}
