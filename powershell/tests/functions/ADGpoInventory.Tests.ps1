BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'AD GPO version normalization' {
    It 'normalizes signed directory versions and preserves missing values' -ForEach @(
        @{ Raw = -1; Expected = 4294967295L }
        @{ Raw = 65538; Expected = 65538L }
        @{ Raw = $null; Expected = $null }
    ) {
        InModuleScope Maester -Parameters @{ Raw = $Raw; Expected = $Expected } {
            param($Raw, $Expected)
            $script:rawVersion = $Raw
            Mock Invoke-MtLdapSearch {
                [PSCustomObject]@{
                    name = '{11111111-1111-1111-1111-111111111111}'
                    displayName = 'Policy'
                    versionNumber = $script:rawVersion
                    ntSecurityDescriptor = $null
                }
            }
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $gpo = @(Get-MtLdapGpo -Connection $connection -SearchBase 'DC=example,DC=com')[0]
                if ($null -eq $Expected) {
                    $null -eq $gpo.VersionNumber | Should -BeTrue
                    $null -eq $gpo.UserVersion | Should -BeTrue
                    $null -eq $gpo.ComputerVersion | Should -BeTrue
                }
                else { $gpo.VersionNumber | Should -Be $Expected }
            }
            finally { $connection.Dispose() }
        }
    }
}

Describe 'AD GPO modification age and link inventories' {
    BeforeEach {
        $script:now = [DateTimeOffset]'2026-11-08T12:00:00+00:00'
        $script:state = [pscustomobject]@{
            GPOs = @([pscustomobject]@{
                    Id = '{11111111-1111-1111-1111-111111111111}'
                    DisplayName = 'Policy | pilot'
                    CreationTime = [datetime]::new(2000, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
                    ModificationTime = [datetime]::new(2026, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
                })
            GPOLinks = @([pscustomobject]@{ GpoGuid = '11111111-1111-1111-1111-111111111111' })
            LinkContainers = @([pscustomobject]@{ ObjectClass = @('organizationalUnit'); DistinguishedName = 'OU=Pilot|test,DC=example,DC=com'; GpLink = '' })
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
        $script:state.GPOs[0].ModificationTime = [datetime]::new(2021, 11, 8, 11, 59, 59, [DateTimeKind]::Utc)
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeFalse }
    }

    It 'accepts a modification exactly at the cutoff' {
        $script:state.GPOs[0].ModificationTime = $script:now.UtcDateTime.AddYears(-5)
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeTrue }
    }

    It 'honors a configurable age limit' {
        $script:state.GPOs[0].ModificationTime = [datetime]::new(2022, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        InModuleScope Maester { Test-MtAdGpoStale -MaximumModificationAgeYears 3 | Should -BeFalse }
    }

    It 'rejects invalid age limits' {
        InModuleScope Maester { { Test-MtAdGpoStale -MaximumModificationAgeYears 0 } | Should -Throw }
    }

    It 'errors on missing modification dates' {
        $script:state.GPOs[0].ModificationTime = $null
        InModuleScope Maester { { Test-MtAdGpoStale } | Should -Throw '*no modification date*' }
    }

    It 'uses the exact UTC cutoff with a non-UTC clock' {
        $script:now = [DateTimeOffset]'2026-11-20T12:00:00-05:00'
        $script:state.GPOs[0].ModificationTime = [datetime]::new(2021, 11, 20, 14, 0, 0, [DateTimeKind]::Utc)
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '2021-11-20 17' }
        $script:state.GPOs[0].ModificationTime = [datetime]::new(2021, 11, 20, 17, 0, 0, [DateTimeKind]::Utc)
        InModuleScope Maester { Test-MtAdGpoStale | Should -BeTrue }
    }

    It 'errors on an empty inventory instead of passing' {
        $script:state.GPOs = @()
        InModuleScope Maester { { Test-MtAdGpoStale } | Should -Throw '*inventory is empty*' }
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

    It 'investigates the GPO inventory' {
        InModuleScope Maester { Test-MtAdGpoTotalCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'investigates a target without direct links without claiming missing effective policy' {
        InModuleScope Maester { Test-MtAdGpoUnlinkedTargetCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $Investigate -and $Result -match 'OU=Pilot&#124;test' -and $Result -match 'OUs with direct links \| 0'
        }
    }

    It 'counts OUs with direct links without claiming effective coverage' {
        $script:state.LinkContainers[0].GpLink = '[LDAP://CN={11111111-1111-1111-1111-111111111111},CN=Policies,DC=example,DC=com;1]'
        InModuleScope Maester { Test-MtAdGpoUnlinkedTargetCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'OUs with direct links \| 1' }
    }
}
