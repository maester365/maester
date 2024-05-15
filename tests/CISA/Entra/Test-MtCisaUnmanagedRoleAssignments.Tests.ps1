BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.5", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.7.5: Provisioning users to highly privileged roles SHALL NOT occur outside of a PAM system." {
        Test-MtCisaUnmanagedRoleAssignment | Should -Be $true -Because "no unmanaged active role assignments exist."
    }
}