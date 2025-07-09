Describe "Microsoft Defender for Endpoint - Policy Design Quality" -Tag "Maester", "MDE", "Security", "All", "MDE-PolicyDesign", "ManualReview" {

    # Policy Design Quality Tests (MDE.PD01 to MDE.PD04) - Using Unified Test Engine
    It "MDE.PD01: Policy naming should follow consistent convention (ROLE-v#). See https://maester.dev/docs/tests/MDE.PD01" -Tag "MDE.PD01" {
        <#
            Verify that policy naming follows consistent convention (e.g., AV-PL-Client-Gen-v1).
            Category: Policy Design | Severity: Low

            Manual Review Required:
            - Check all MDE policy names in Microsoft Endpoint Manager
            - Verify naming follows organizational standard (ROLE-v#)
            - Example: AV-PL-Client-Gen-v1, AV-EX-Server-DB-v2
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.PD01" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "policy naming should follow consistent convention"
            }
        }
    }

    It "MDE.PD02: Exclusions should be in dedicated profiles. See https://maester.dev/docs/tests/MDE.PD02" -Tag "MDE.PD02" {
        <#
            Verify that exclusions are configured in dedicated profiles to reduce baseline complexity.
            Category: Policy Design | Severity: Medium

            Manual Review Required:
            - Review MDE exclusion policies in Microsoft Endpoint Manager
            - Verify exclusions are separated from baseline antivirus policies
            - Check that baseline policies are kept clean and focused
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.PD02" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "exclusions should be configured in dedicated profiles"
            }
        }
    }

    It "MDE.PD03: Device profiles should be granular (Least Privilege). See https://maester.dev/docs/tests/MDE.PD03" -Tag "MDE.PD03" {
        <#
            Verify that device profiles are granular and follow least privilege principle.
            Category: Policy Design | Severity: Medium

            Manual Review Required:
            - Review device group assignments in Microsoft Endpoint Manager
            - Verify policies are targeted to specific device types/roles
            - Check that policies follow least privilege access patterns
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.PD03" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "device profiles should be granular and follow least privilege principle"
            }
        }
    }

    It "MDE.PD04: Staging buckets should be implemented (Pilot → Prod). See https://maester.dev/docs/tests/MDE.PD04" -Tag "MDE.PD04" {
        <#
            Verify that staging deployment buckets are implemented (e.g., DG-CL-GEN-PILOT → PROD).
            Category: Policy Design | Severity: Medium

            Manual Review Required:
            - Review device group structure in Microsoft Endpoint Manager
            - Verify pilot groups exist (e.g., DG-CL-GEN-PILOT)
            - Check staged rollout process is documented and followed
        #>
        $result = Invoke-MtMdeUnifiedTest -TestId "MDE.PD04" -TestName $____Pester.CurrentTest.ExpandedName
        if ($null -ne $result) {
            if ($result.IsSkipped) {
                # Add test details for skipped tests to ensure they appear in HTML reports
                Add-MtTestResultDetail -Description $result.TestDetails -GraphObjectType 'Devices' -Severity $result.Severity
                Set-ItResult -Skipped -Because $result.SkipReason
            } else {
                $result | Should -Be $true -Because "staging deployment buckets should be implemented"
            }
        }
    }
}