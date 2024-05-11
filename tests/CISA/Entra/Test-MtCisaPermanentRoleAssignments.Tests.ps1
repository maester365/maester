BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.4", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.7.4: Permanent active role assignments SHALL NOT be allowed for highly privileged roles." {
        Test-MtCisaPermanentRoleAssignments | Should -Be $true -Because "no permanently active privileged role assignments exist."
    }
}