Describe 'Maester/Entra' -Tag 'Maester', 'Entra', 'Graph' {
    It 'MT.1200: Agent Identities should have an existing Blueprint Principal. See https://maester.dev/docs/tests/MT.1200' -Tag 'MT.1200', 'Severity:Medium' {
        $Result = Test-MtEntraAgentIdentityOrphaned

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because 'Agent Identities should have an existing Blueprint Principal'
        }
    }

    It 'MT.1201: Agent Users should have an existing parent Agent Identity. See https://maester.dev/docs/tests/MT.1201' -Tag 'MT.1201', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentUserOrphaned

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because 'Agent Users should have a matching Agent Identity'
        }
    }
}
