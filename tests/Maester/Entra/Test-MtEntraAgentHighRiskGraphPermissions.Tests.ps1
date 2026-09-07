Describe 'Maester/Entra' -Tag 'Maester', 'Entra' {
    It 'MT.1223: Agent Identities should not have high-risk Microsoft Graph permissions (Preview). See https://maester.dev/docs/tests/MT.1223' -Tag 'MT.1223', 'Severity:High', 'Preview', 'LongRunning' {
        $Result = Test-MtEntraAgentHighRiskGraphPermissions

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Agent Identities should use least-privilege Microsoft Graph permissions'
            )
        }
    }
}
