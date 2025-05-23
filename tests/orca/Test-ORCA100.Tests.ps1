# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.100", "EXO", "Security", "All" {
    It "ORCA.100: Bulk Complaint Level threshold is between 4 and 6." {
        $result = Test-ORCA100

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk Complaint Level threshold is between 4 and 6."
        }
    }
}
