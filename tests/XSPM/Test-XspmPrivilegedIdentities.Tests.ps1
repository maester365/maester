BeforeDiscovery {
    try {
        $DefenderPlan = Get-MtLicenseInformation -Product "DefenderXDR"
    } catch {
        $DefenderPlan = "NotConnected"
    }
}

Describe "Exposure Management" -Tag "Privileged", "Entra", "Graph", "LongRunning", "Security", "EntraOps", "XSPM" -Skip:( $DefenderPlan -ne "DefenderXDR" ) {
    # Privileged assets, identified by EntraOps and Critical Asset Management, should not be exposed due to weak security configurations.
    It "MT.1077: App registrations with privileged API permissions should not have owners. See https://maester.dev/docs/tests/MT.1077" -Tag "MT.1077" {
        Test-MtXspmAppRegWithPrivilegedApiAndOwners | Should -Be $true -Because "an app registration with privileged API permissions should not have assigned owner, as permanent and/or lower privileged users have full control over privileged application and may lead to privilege escalation."
    }

    It "MT.1078: App registrations with highly privileged directory roles should not have owners. See https://maester.dev/docs/tests/MT.1078" -Tag "MT.1078" {
        Test-MtXspmAppRegWithPrivilegedRolesAndOwners | Should -Be $true -Because "an app registration with highly privileged directory roles should not have assigned owner, as permanent and/or lower privileged users have full control over privileged application and may lead to privilege escalation."
    }

    It "MT.1079: Privileged API permissions on service principals should not remain unused. See https://maester.dev/docs/tests/MT.1079" -Tag "MT.1079" {
        Test-MtXspmAppRegWithPrivilegedUnusedPermissions | Should -Be $true -Because "an app registration with highly privileged API permissions should not have unused permissions, to minimize the attack surface and follow least privilege principles."
    }

    It "MT.1080: Credentials, tokens, or cookies from highly privileged users should not be exposed on vulnerable endpoints. See https://maester.dev/docs/tests/MT.1080" -Tag "MT.1080" {
        Test-MtXspmExposedCredentialsForPrivilegedUsers | Should -Be $true -Because "Azure CLI secrets, tokens, or user cookies from highly privileged users should not be exposed on vulnerable endpoints."
    }

    It "MT.1081: Hybrid users should not be assigned Entra ID role assignments. See https://maester.dev/docs/tests/MT.1081" -Tag "MT.1081" {
        Test-MtXspmHybridUsersWithAssignedEntraIdRoles | Should -Be $true -Because "Hybrid users should not be assigned to eligible or permanent Entra ID role assignments to avoid lateral movement by compromised Active Directory."
    }
}
