Describe "MDE" -Tag "Maester", "MDE", "MDE-PolicyDesign", "Defender", "Security", "All" {
    It "MDE.PD01: Policy naming should follow consistent convention (ROLE-v#). See https://maester.dev/docs/tests/MDE.PD01" -Tag "MDE.PD01" {
        $result = Test-MtMdePolicyNamingConvention
        if ($null -ne $result) {
            $result | Should -Be $true -Because "policy naming should follow consistent convention"
        }
    }

    It "MDE.PD02: Exclusions should be in dedicated profiles. See https://maester.dev/docs/tests/MDE.PD02" -Tag "MDE.PD02" {
        $result = Test-MtMdeExclusionProfiles
        if ($null -ne $result) {
            $result | Should -Be $true -Because "exclusions should be configured in dedicated profiles"
        }
    }

    It "MDE.PD03: Device profiles should be granular (Least Privilege). See https://maester.dev/docs/tests/MDE.PD03" -Tag "MDE.PD03" {
        $result = Test-MtMdeGranularDeviceTargeting
        if ($null -ne $result) {
            $result | Should -Be $true -Because "device profiles should be granular and follow least privilege principle"
        }
    }

    It "MDE.PD04: Staging buckets should be implemented (Pilot → Prod). See https://maester.dev/docs/tests/MDE.PD04" -Tag "MDE.PD04" {
        $result = Test-MtMdeStagingDeployment
        if ($null -ne $result) {
            $result | Should -Be $true -Because "staging deployment buckets should be implemented"
        }
    }
}
