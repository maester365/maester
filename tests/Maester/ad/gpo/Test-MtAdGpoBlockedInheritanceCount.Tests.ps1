BeforeAll {
    # Ensure the Maester module and the target command are available when running this test directly.
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../../')
    Import-Module (Join-Path $projectRoot 'powershell/Maester.psd1') -Force | Out-Null

    if (-not (Get-Command Test-MtAdGpoBlockedInheritanceCount -ErrorAction SilentlyContinue)) {
        . (Join-Path $projectRoot 'powershell/public/ad/gpo/Test-MtAdGpoBlockedInheritanceCount.ps1')
    }
}

Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPOL-05" {
    It "AD-GPOL-05: GPO blocked inheritance count should be compliant" {
        $result = Test-MtAdGpoBlockedInheritanceCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Blocked inheritance should not be configured on any OU"
        }
    }
}
