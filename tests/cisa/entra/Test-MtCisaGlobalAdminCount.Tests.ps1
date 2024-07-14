BeforeDiscovery {
    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "RoleEligibilitySchedule.ReadWrite.Directory" -notin $scopes
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.1", "CISA", "Security", "All" -Skip:( $permissionMissing ) {
    It "MS.AAD.7.1: A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role." {
        Test-MtCisaGlobalAdminCount | Should -Be $true -Because "two or more and eight or fewer Global Administrators exist."
    }
}