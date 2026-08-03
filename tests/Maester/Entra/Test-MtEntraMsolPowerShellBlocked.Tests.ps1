Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.1185: Block legacy MSOnline (MSOL) PowerShell module. See https://maester.dev/docs/tests/MT.1185" -Tag "MT.1185" {
        $result = Test-MtEntraMsolPowerShellBlocked
        $result | Should -Be $true -Because "the legacy MSOnline (MSOL) PowerShell module should be blocked from authenticating to the tenant."
    }
}
