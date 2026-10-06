Describe "Maester/Entra" -Tag "Maester", "Privileged" {
}

Describe "Maester/Entra" -Tag "Maester", "Privileged", "PIM" {
    It "MT.1029: Stale accounts are not assigned to privileged roles. See https://maester.dev/docs/tests/MT.1029" -Tag "MT.1029" {
        if ( ( Get-MtLicenseInformation EntraID ) -ne "P2" ) {
            Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        } else {
            $Check = Test-MtPimAlertsExists -AlertId "StaleSignInAlert"
            $check.isActive -eq $false -or $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
        }
    }
    It "MT.1030: Eligible role assignments on Control Plane are in use by administrators. See https://maester.dev/docs/tests/MT.1030" -Tag "MT.1030" {
        if ( ( Get-MtLicenseInformation EntraID ) -ne "P2" ) {
            Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        } else {
            $Check = Test-MtPimAlertsExists -AlertId "RedundantAssignmentAlert" -FilteredAccessLevel "ControlPlane"
            $check.isActive -eq $false -or $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
        }
    }
    It "MT.1031: Privileged role on Control Plane are managed by PIM only. See https://maester.dev/docs/tests/MT.1031" -Tag "MT.1031" {
        if ( ( Get-MtLicenseInformation EntraID ) -ne "P2" ) {
            Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        } else {
            $Check = Test-MtPimAlertsExists -AlertId "RolesAssignedOutsidePimAlert" -FilteredAccessLevel "ControlPlane"
            $check.isActive -eq $false -or $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
        }
    }
    It "MT.1032: Limited number of Global Admins are assigned. See https://maester.dev/docs/tests/MT.1032" -Tag "MT.1032" {
        if ( ( Get-MtLicenseInformation EntraID ) -ne "P2" ) {
            Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        } else {
            $Check = Test-MtPimAlertsExists -AlertId "TooManyGlobalAdminsAssignedToTenantAlert"
            $check.isActive -eq $false -or $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
        }
    }
}
