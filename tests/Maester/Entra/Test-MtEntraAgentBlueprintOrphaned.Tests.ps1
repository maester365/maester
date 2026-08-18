Describe 'Maester/Entra' -Tag 'Maester', 'Entra', 'Graph', 'Agent ID' {
    It 'MT.3000: Agent Identity Blueprint Principals should have an existing Blueprint. See https://maester.dev/docs/tests/MT.3000' -Tag 'MT.3000', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintOrphaned

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Blueprint Principals should have an existing Agent Identity Blueprint'
            )
        }
    }
}
