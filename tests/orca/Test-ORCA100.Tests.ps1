# Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA100", "EXO", "Security", "All" {
    It "ORCA100: Bulk Complaint Level" {
        $result = Test-ORCA100

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk Complaint Level threshold is between 4 and 6"
        }
    }
}
