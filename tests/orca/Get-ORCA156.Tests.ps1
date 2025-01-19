# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA156", "EXO", "Security", "All" {
    It "ORCA156: Safe Links Tracking" {
        $result = Get-ORCA156

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links Policies are tracking when user clicks on safe links"
        }
    }
}
