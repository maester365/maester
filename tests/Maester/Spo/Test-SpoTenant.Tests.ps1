BeforeDiscovery {

    # Check for prerequisite before running the tests. If the prerequisites are not met, return $null to skip the tests.
    # Following checks are performed to to current limitations of the Microsoft.Online.SharePoint.PowerShell module:
    # - Run on Windows OS
    # - Run in PowerShell 5 not 7
    # - Check if the module is installed and loaded
    # - Check if the user is connected to SharePoint Online with Connect-SpoService
    if (-not ($PSVersionTable.OS -match "Windows" -or [System.Environment]::OSVersion.VersionString -match "Windows")) {
        Write-Host "SharePoint Online tests can only be run on Windows OS. Skipping tests..." -ForegroundColor Yellow
        return $null
    }
    if ($PSVersionTable.PSVersion.Major -ne 5) {
        Write-Host "SharePoint Online tests can only be run in PowerShell 5. Skipping tests..." -ForegroundColor Yellow
        return $null
    }
    if (-not (Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        Write-Host "Microsoft.Online.SharePoint.PowerShell module is not installed. Skipping tests..." -ForegroundColor Yellow
        return $null
    }
    if (-not (Get-Module -Name Microsoft.Online.SharePoint.PowerShell)) {
        Write-Host "Microsoft.Online.SharePoint.PowerShell module is not imported. Skipping tests..." -ForegroundColor Yellow
        return $null
    }
    if (-not (Get-SpoTenant)) {
        Write-Host "Not connected to SharePoint Online. Please connect using Connect-SpoService before running the tests. Skipping tests..." -ForegroundColor Yellow
        return $null
    }
}

Describe 'Maester/SpoTenant' -Tag 'Maester', 'SpoTenant' {
    It 'MT.1113: Ensure your SharePoint tenant is integrated with Microsoft Entra B2B for external sharing.' -Tag 'MT.1113', 'CIS', 'CIS M365v5', 'CIS 7.2.2', 'Severity:Medium' {
        $result = Test-MtSpoB2BIntegration
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'SharePoint tenant is integrated with Microsoft Entra B2B.'
        }
    }
    It 'MT.1114: Ensure Office 365 SharePoint infected files are disallowed for download' -Tag 'MT.1114', 'CIS', 'CIS M365v5', 'CIS 7.3.1', 'Severity:High' {
        $result = Test-MtSpoPreventDownloadMaliciousFile
        if ($null -ne $result) {
            $result | Should -Be $true -Because 'Office 365 SharePoint infected files are disallowed for download.'
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
    It "MT.1118: Ensure that SharePoint guest users cannot share items they don't own" -Tag 'MT.1118', 'CIS', 'CIS M365v5', 'CIS 7.2.5', 'Severity:High' {
        $result = Test-MtSpoGuestCannotShareUnownedItem
        if ($null -ne $result) {
            $result | Should -Be $true -Because "SharePoint guest users cannot share items they don't own."
        }
    }

}