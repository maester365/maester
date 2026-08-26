Describe 'Maester/Entra' -Tag 'Maester', 'Entra', 'Graph', 'Agent ID' {
    It 'MT.1204: Agent Identities, Blueprint Principals, and Blueprints should have active, enabled owners (Preview). See https://maester.dev/docs/tests/MT.1204' -Tag 'MT.1204', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentOwner

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'All Agent Identities, Blueprint Principals, and Blueprints should have active, enabled owners'
            )
        }
    }

    It 'MT.1205: Agent Identity Blueprints and Blueprint Principals should have assigned sponsors (Preview). See https://maester.dev/docs/tests/MT.1205' -Tag 'MT.1205', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentSponsor

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprints and Blueprint Principals should have assigned sponsors'
            )
        }
    }

    It 'MT.1206: Enabled Agent Identities should have active sign-in activity within the last 180 days (Preview). See https://maester.dev/docs/tests/MT.1206' -Tag 'MT.1206', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentInactive

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Enabled Agent Identities should have sign-in activity within the last 180 days'
            )
        }
    }

    It 'MT.1207: Foreign or multi-tenant Agent Blueprint Principals and Agent Identities should not hold privileged directory roles (Preview). See https://maester.dev/docs/tests/MT.1207' -Tag 'MT.1207', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentForeignPrivileged

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Foreign or multi-tenant Agent ID objects should not hold privileged directory roles'
            )
        }
    }

    It 'MT.1208: Agent Identity Blueprints should not have expired, excessive, or long-lived client credentials (Preview). See https://maester.dev/docs/tests/MT.1208' -Tag 'MT.1208', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintCredentialHygiene

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprints should maintain healthy credential lifecycles without expired or excessive secrets'
            )
        }
    }

    It 'MT.1209: Agent Identities and Blueprint Principals should not be assigned privileged Entra directory roles (Preview). See https://maester.dev/docs/tests/MT.1209' -Tag 'MT.1209', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentDirectoryRoles

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identities and Blueprint Principals should use least-privilege permissions instead of directory roles'
            )
        }
    }

    It 'MT.1210: Agent Users should not have privileged directory roles or membership in role-assignable groups (Preview). See https://maester.dev/docs/tests/MT.1210' -Tag 'MT.1210', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentUserExcessiveAccess

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Users should not have directory administrative roles or membership in role-assignable groups'
            )
        }
    }

    It 'MT.1211: Agent Identity Blueprints should not use the allAllowed inheritance pattern for delegated scopes or application roles (Preview). See https://maester.dev/docs/tests/MT.1211' -Tag 'MT.1211', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintAllAllowedInheritance

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprints should not use the allAllowed inheritance pattern for delegated scopes or application roles'
            )
        }
    }

    It 'MT.1212: Agent Identity Blueprint Principals should require assignment for the application roles they expose (Preview). See https://maester.dev/docs/tests/MT.1212' -Tag 'MT.1212', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintOpenAccess

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprint Principals should require assignment for the application roles they expose'
            )
        }
    }

    It 'MT.1213: Agent Identity Blueprints should not use wildcard or plain-http redirect URIs (Preview). See https://maester.dev/docs/tests/MT.1213' -Tag 'MT.1213', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintRedirectUriHygiene

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprints should not use wildcard or plain-http redirect URIs'
            )
        }
    }
}
