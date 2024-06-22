BeforeDiscovery {
    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "RoleEligibilitySchedule.ReadWrite.Directory" -notin $scopes
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.2", "CISA", "Security", "All" -Skip:( $permissionMissing ) {
    It "MS.AAD.7.2: Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator." {
        Test-MtCisaGlobalAdminRatio | Should -Be $true -Because "more granular role assignments exist than global admin assignments."
    }
}