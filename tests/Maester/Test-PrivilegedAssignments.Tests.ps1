Describe "Directory Roles - Permanent assignments" -Tag "Privileged", "Security", "All" {
    It "MT.1021: No external user with permanent and high-privileges in Entra ID. See https://maester.dev/docs/tests/MT.1021" {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ExternalUser"
        $Check | Should -Be $false -Because "External user shouldn't have high-privileged roles"
    }
    It "MT.1022: No hybrid user with permanent and Control Plane assignment to Control Plane role. See https://maester.dev/docs/tests/MT.1022" {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "HybridUser"
        $Check | Should -Be $false -Because "Hybrid user with access to high-privileged directory roles which should be avoided"
    }
    It "MT.1023: No Service Principal with Client Secret and permanent assignment to Control Plane role. See https://maester.dev/docs/tests/MT.1023" {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ServicePrincipalClientSecret"
        $Check | Should -Be $false -Because "Service Principal with assignments to high-privileged roles should not using Client Secret"
    }
    It "MT.1024: No user with mailbox and permanent assignment to Control Plane role. See https://maester.dev/docs/tests/MT.1024" {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "UserMailbox"
        $Check | Should -Be $false -Because "Privileged user with assignment to high-privileged roles should not be mail-enabled which could be a risk for phishing attacks"
    }
}


Describe "Privileged Identity Management - Eligible assignments" -Tag "Privileged", "Security", "All" {
    It "MT.1025: Stale accounts are not assigned to privileged roles. See https://maester.dev/docs/tests/MT.1025" {
        $Check = Test-MtPimAlertsExists -AlertId "StaleSignInAlert"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
    It "MT.1026: Eligible role assignments on Control Plane are in use by administrators. See https://maester.dev/docs/tests/MT.1026" {
        $Check = Test-MtPimAlertsExists -AlertId "RedundantAssignmentAlert" -FilteredAccessLevel "ControlPlane"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
    It "MT.1027: Privileged role on Control Plane are by PIM only. See https://maester.dev/docs/tests/MT.1027" {
        $Check = Test-MtPimAlertsExists -AlertId "RolesAssignedOutsidePimAlert" -FilteredAccessLevel "ControlPlane"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
    It "MT.1028: Limited number of Global Admins are assigned. See https://maester.dev/docs/tests/MT.1028" {
        $Check = Test-MtPimAlertsExists -AlertId "TooManyGlobalAdminsAssignedToTenantAlert"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
}