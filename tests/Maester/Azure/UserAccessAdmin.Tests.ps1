Describe "AzureConfig" -Tag "Privilege", "Azure" {
    It "MT.1056: Ensure that no person has permanent access to all Azure subscriptions at the root scope" {

        $result = Test-MtUserAccessAdmin

        $result | Should -Be $true -Because "No user should have administrator access at root scope"}
}