# Legacy Pester fixture: a stale copy of a 2.x built-in wrapper, as left in a user's folder
# by an old Install-MaesterTests. Its ID is a current built-in ID, so 3.0 supersedes it
# (not executed, no row, one warning). Calls a built-in function.
Describe "Maester/Entra" -Tag "Maester", "CA" {
    It "MT.1001: At least one Conditional Access policy is configured with device compliance. See https://maester.dev/docs/tests/MT.1001" -Tag "MT.1001" {
        Test-MtCaDeviceComplianceExists | Should -Be $true -Because "there is no policy which requires device compliances"
    }
}
