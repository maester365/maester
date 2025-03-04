# Generated on 03/04/2025 10:12:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA101", "EXO", "Security", "All" {
    It "ORCA101: Bulk is marked as spam." {
        $result = Test-ORCA101

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk is marked as spam."
        }
    }
}
