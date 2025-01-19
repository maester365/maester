# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA236", "EXO", "Security", "All" {
    It "ORCA236: Safe Links protections for links in email" {
        $result = Get-ORCA236

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for emails"
        }
    }
}
