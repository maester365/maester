# Generated on 01/18/2025 19:34:46 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA101", "EXO", "Security", "All" {
    It "ORCA101: Mark Bulk as Spam" {
        $result = Test-ORCA101

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk is marked as spam"
        }
    }
}
