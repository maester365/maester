Describe 'Maester/Entra' -Tag 'Maester', 'Entra', 'Graph', 'Agent ID' {
    It 'MT.1203: Agent Identity Blueprint Principals should have an existing Blueprint (Preview). See https://maester.dev/docs/tests/MT.1203' -Tag 'MT.1203', 'Severity:Medium', 'Preview' {
        $Result = Test-MtEntraAgentBlueprintOrphaned

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because (
                'Blueprint Principals should have an existing Agent Identity Blueprint'
            )
        }
    }
}
