# Generated on 03/04/2025 09:42:22 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA100", "EXO", "Security", "All" {
    It "ORCA100: Bulk Complaint Level threshold is between 4 and 6." {
        $result = Test-ORCA100

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk Complaint Level threshold is between 4 and 6."
        }
    }
}
