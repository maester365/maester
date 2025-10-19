Describe 'Maester/Entra' -Tag 'App', 'Entra', 'Full', 'Graph', 'LongRunning', 'Preview' {
    It 'MT.1050: Apps with high-risk permissions having a direct path to Global Admin' -Tag 'MT.1050' {
        $result = Test-MtHighRiskAppPermissions -AttackPath 'Direct'
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'no graph application has permissions with a risk of having a direct path to Global Admin and full tenant takeover.'
        }
    }

    It 'MT.1051: Apps with high-risk permissions having an indirect path to Global Admin' -Tag 'MT.1051' {
        $result = Test-MtHighRiskAppPermissions -AttackPath 'Indirect'
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'no graph application has permissions with a risk of having an indirect path to Global Admin and full tenant takeover.'
        }
    }
}
