Describe "AzureConfig" -Tag "Governance", "Azure" {
    It "MT.1064: Ensure that write permissions are required to create new management groups" -Tag "MT.1064" {

        $result = Test-MtManagementGroupWriteRequirement

        $result | Should -Be $true -Because "Management group creation should be limited to users with explicit write access"
    }
}
