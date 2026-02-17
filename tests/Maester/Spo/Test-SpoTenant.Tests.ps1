Describe 'Maester/SpoTenant' -Tag 'Maester', 'SpoTenant' {
    It 'MT.1113: Ensure your SharePoint tenant is integrated with Microsoft Entra B2B for external sharing.' -Tag 'MT.1113', 'CIS', 'CIS M365v5', 'CIS 7.2.2', 'Severity:Medium' {
        $result = Test-MtSpoB2BIntegration
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'SharePoint tenant is integrated with Microsoft Entra B2B.'
        }
    }
    It 'MT.1114: Ensure custom script execution is restricted on site collections' -Tag 'MT.1114', 'CIS', 'CIS M365v5', 'CIS 7.3.4', 'Severity:Medium' {
        $result = Test-MtSpoCustomScriptExecutionOnSiteCollection
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'custom script execution is restricted on site collections.'
        }
    }
    It 'MT.1115: Ensure link sharing is restricted in SharePoint and OneDrive' -Tag 'MT.1115', 'CIS', 'CIS M365v5', 'CIS 7.2.7', 'Severity:Low' {
        $result = Test-MtSpoDefaultSharingLink
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'link sharing is restricted in SharePoint and OneDrive.'
        }
    }
    It 'MT.1116: Ensure the SharePoint default sharing link permission is set' -Tag 'MT.1116', 'CIS', 'CIS M365v5', 'CIS 7.2.11', 'Severity:Low' {
        $result = Test-MtSpoDefaultSharingLinkPermission
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'the SharePoint default sharing link permission is set.'
        }
    }
    It 'MT.1117: Ensure guest access to a site or OneDrive will expire automatically' -Tag 'MT.1117', 'CIS', 'CIS M365v5', 'CIS 7.2.9', 'Severity:Low' {
        $result = Test-MtSpoGuestAccessExpiry
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'guest access to a site or OneDrive will expire automatically.'
        }
    }
    It 'MT.1118: Ensure that SharePoint guest users cannot share items they dont own' -Tag 'MT.1118', 'CIS', 'CIS M365v5', 'CIS 7.2.5', 'Severity:High' {
        $result = Test-MtSpoGuestCannotShareUnownedItem
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'SharePoint guest users cannot share items they dont own.'
        }
    }
    It 'MT.1119: Ensure Office 365 SharePoint infected files are disallowed for download' -Tag 'MT.1119', 'CIS', 'CIS M365v5', 'CIS 7.3.1', 'Severity:High' {
        $result = Test-MtSpoPreventDownloadMaliciousFile
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'Office 365 SharePoint infected files are disallowed for download.'
        }
    }
}