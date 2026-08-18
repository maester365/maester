Describe 'Maester/Entra' -Tag 'Maester', 'Entra', 'Graph', 'Agent ID' {
    It 'MT.3001: Agent Identities, Blueprint Principals, and Blueprints should have active, enabled owners. See https://maester.dev/docs/tests/MT.3001' -Tag 'MT.3001', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentOwner

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'All Agent Identities, Blueprint Principals, and Blueprints should have active, enabled owners'
            )
        }
    }

    It 'MT.3002: Agent Identity Blueprints and Blueprint Principals should have assigned sponsors. See https://maester.dev/docs/tests/MT.3002' -Tag 'MT.3002', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentSponsor

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprints and Blueprint Principals should have assigned sponsors'
            )
        }
    }

    It 'MT.3003: Enabled Agent Identities should have active sign-in activity within the last 180 days. See https://maester.dev/docs/tests/MT.3003' -Tag 'MT.3003', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentInactive

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Enabled Agent Identities should have sign-in activity within the last 180 days'
            )
        }
    }

    It 'MT.3004: Foreign or multi-tenant Agent Blueprint Principals and Agent Identities should not hold privileged directory roles. See https://maester.dev/docs/tests/MT.3004' -Tag 'MT.3004', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentForeignPrivileged

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Foreign or multi-tenant Agent ID objects should not hold privileged directory roles'
            )
        }
    }

    It 'MT.3005: Agent Identity Blueprints should not have expired, excessive, or long-lived client credentials. See https://maester.dev/docs/tests/MT.3005' -Tag 'MT.3005', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintCredentialHygiene

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identity Blueprints should maintain healthy credential lifecycles without expired or excessive secrets'
            )
        }
    }

    It 'MT.3006: Agent Identities and Blueprint Principals should not be assigned privileged Entra directory roles. See https://maester.dev/docs/tests/MT.3006' -Tag 'MT.3006', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentDirectoryRoles

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identities and Blueprint Principals should use least-privilege permissions instead of directory roles'
            )
        }
    }

    It 'MT.3007: Agent Users should not have privileged directory roles or membership in role-assignable groups. See https://maester.dev/docs/tests/MT.3007' -Tag 'MT.3007', 'Severity:High', 'Preview' {
        $Result = Test-MtEntraAgentUserExcessiveAccess

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Users should not have directory administrative roles or membership in role-assignable groups'
            )
        }
    }
}
