BeforeDiscovery {
    $AvailablePlans = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/organization" | Select-Object -ExpandProperty value | Select-Object -ExpandProperty assignedPlans | Where-Object service -EQ "AADPremiumService" | Select-Object -ExpandProperty servicePlanId
    if ( "eec0eb4f-6444-4f95-aba0-50c24d67f998" -in $AvailablePlans ) {
        $EntraIDPlan = "P2"
    } elseif ( "41781fb2-bc02-4b7c-bd55-b576c07bb09d)" -in $AvailablePlans ) {
        $EntraIDPlan = "P1"
    } else {
        $EntraIDPlan = "Free"
    }
}

Describe "Directory Roles - Permanent assignments" -Tag "Privileged", "Security", "All" {
    It "MT.1024: No external user with permanent and high-privileges in Entra ID." {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ExternalUser"
        $Check | Should -Be $false -Because "External user shouldn't have high-privileged roles"
    }
    It "MT.1025: No hybrid user with permanent and assignment on Control Plane role." {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "HybridUser"
        $Check | Should -Be $false -Because "Hybrid user with access to high-privileged directory roles which should be avoided"
    }
    It "MT.1026: No Service Principal with Client Secret and permanent assignment on Control Plane role." {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ServicePrincipalClientSecret"
        $Check | Should -Be $false -Because "Service Principal with assignments to high-privileged roles should not using Client Secret"
    }
    It "MT.1027: No user with mailbox and permanent assignment on Control Plane role." {
        $Check = Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "UserMailbox"
        $Check | Should -Be $false -Because "Privileged user with assignment to high-privileged roles should not be mail-enabled which could be a risk for phishing attacks"
    }
}

Describe "Privileged Identity Management (PIM) - Alerts" -Tag "Privileged", "Security", "All" -Skip:( $EntraIDPlan -ne "P2" ) {
    It "MT.1028: Stale accounts are not assigned to privileged roles. See https://maester.dev/docs/tests/MT.1025" {
        $Check = Test-MtPimAlertsExists -AlertId "StaleSignInAlert"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
    It "MT.1029: Eligible role assignments on Control Plane are in use by administrators." -Skip:( $EntraIDPlan -ne "P2" ) {
        $Check = Test-MtPimAlertsExists -AlertId "RedundantAssignmentAlert" -FilteredAccessLevel "ControlPlane"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
    It "MT.1030: Privileged role on Control Plane are managed by PIM only." -Skip:( $EntraIDPlan -ne "P2" ) {
        $Check = Test-MtPimAlertsExists -AlertId "RolesAssignedOutsidePimAlert" -FilteredAccessLevel "ControlPlane"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
    It "MT.1031: Limited number of Global Admins are assigned." -Skip:( $EntraIDPlan -ne "P2" ) {
        $Check = Test-MtPimAlertsExists -AlertId "TooManyGlobalAdminsAssignedToTenantAlert"
        $check.numberOfAffectedItems -eq "0" | Should -Be $true -Because $check.securityImpact
    }
}