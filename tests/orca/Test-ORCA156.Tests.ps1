# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA156", "EXO", "Security", "All" {
    It "ORCA156: Safe Links Policies are tracking when user clicks on safe links." {
        $result = Test-ORCA156

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links Policies are tracking when user clicks on safe links."
        }
    }
}
