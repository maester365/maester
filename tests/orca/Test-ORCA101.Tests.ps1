# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.101", "EXO", "Security" {
    It "ORCA.101: Bulk is marked as spam." {
        $result = Test-ORCA101

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk is marked as spam."
        }
    }
}
