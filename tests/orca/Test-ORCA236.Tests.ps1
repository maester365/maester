# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA236", "EXO", "Security", "All" {
    It "ORCA236: Safe Links protections for links in email" {
        $result = Test-ORCA236

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for emails"
        }
    }
}
