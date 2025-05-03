Describe "AzureConfig" -Tag "Privilege", "Azure" {
    It "MT. Check 'User Access Administrators' at root scope" {

        $result = Test-MtUserAccessAdmin

        $result | Should -Be $true -Because "No User Access Administrators at root scope"}
}