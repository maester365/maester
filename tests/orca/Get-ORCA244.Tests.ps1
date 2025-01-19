# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA244", "EXO", "Security", "All" {
    It "ORCA244: Honor DMARC Policy" {
        $result = Get-ORCA244

        if($null -ne $result) {
            $result | Should -Be $true -Because "Policies are configured to honor sending domains DMARC."
        }
    }
}
