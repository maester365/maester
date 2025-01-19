# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA100", "EXO", "Security", "All" {
    It "ORCA100: Bulk Complaint Level" {
        $result = Get-ORCA100

        if($null -ne $result) {
            $result | Should -Be $true -Because "Bulk Complaint Level threshold is between 4 and 6"
        }
    }
}
