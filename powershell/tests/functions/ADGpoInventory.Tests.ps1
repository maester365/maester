BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'AD GPO modification age and link inventories' {
    BeforeEach {
        $script:now = [datetime]'2026-11-08T12:00:00'
        $script:state = [pscustomobject]@{
            GPOs = @([pscustomobject]@{
                    Id = '{11111111-1111-1111-1111-111111111111}'
                    DisplayName = 'Policy | pilot'
                    CreationTime = [datetime]'2000-01-01'
                    ModificationTime = [datetime]'2026-01-01'
                })
            GPOLinks = @([pscustomobject]@{ GpoGuid = '11111111-1111-1111-1111-111111111111' })
            LinkContainers = @(
                [pscustomobject]@{ ObjectClass = @('domainDNS'); DistinguishedName = 'DC=example,DC=com'; GpLink = '' }
                [pscustomobject]@{ ObjectClass = @('organizationalUnit'); DistinguishedName = 'OU=Pilot|test,DC=example,DC=com'; GpLink = '' }
            )
            SiteContainers = @()
        }
        Mock -ModuleName Maester Get-MtADGpoState { $script:state }
        Mock -ModuleName Maester Get-Date { $script:now }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'does not fail an old creation date when modification is recent' {
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $Result -match '2000-01-01' -and $Result -match '2026-01-01' -and $Result -match '&#124;'
        }
    }

    It 'fails stale modifications using five years by default' {
        $script:state.GPOs[0].ModificationTime = [datetime]'2021-11-08T11:59:59'
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeFalse }
    }

    It 'accepts a modification exactly at the cutoff' {
        $script:state.GPOs[0].ModificationTime = $script:now.AddYears(-5)
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeTrue }
    }

    It 'honors a configurable age limit' {
        $script:state.GPOs[0].ModificationTime = [datetime]'2022-01-01'
        InModuleScope Maester { Test-MtAdGpoStale -MaximumAgeYears 3 | Should -BeFalse }
    }

    It 'errors on missing modification dates' {
        $script:state.GPOs[0].ModificationTime = $null
        InModuleScope Maester { { Test-MtAdGpoStale } | Should -Throw '*no modification date*' }
    }

    It 'recognizes normalized links despite braces around the inventory identifier' {
        InModuleScope Maester { Test-MtAdGpoUnlinkedCount | Should -BeTrue }
    }

    It 'lists unlinked policies with both dates' {
        $script:state.GPOLinks = @()
        InModuleScope Maester { Test-MtAdGpoUnlinkedCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '2000-01-01' -and $Result -match '2026-01-01' }
    }

    It 'errors rather than treating failed link collection as no links' {
        $script:state.GPOLinks = $null
        InModuleScope Maester { { Test-MtAdGpoUnlinkedCount } | Should -Throw '*cannot be assessed*' }
    }

    It 'investigates a target without direct links without claiming missing effective policy' {
        InModuleScope Maester { Test-MtAdGpoUnlinkedTargetCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'OU=Pilot&#124;test' }
    }
}
