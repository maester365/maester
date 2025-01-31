# Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA101", "EXO", "Security", "All" {
    It "ORCA101: Mark Bulk as Spam" {
        $result = Test-ORCA101

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk is marked as spam"
        }
    }
}
