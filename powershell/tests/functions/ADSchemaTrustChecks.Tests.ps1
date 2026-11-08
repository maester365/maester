BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name @(
        'Test-MtAdSchemaModificationYearCount'
        'Test-MtAdSchemaVersionEntryCount'
        'Test-MtAdLapsInstalledStatus'
        'Test-MtAdSupportedSaslMechanismCount'
        'Test-MtAdManagedServiceAccountCount'
        'Test-MtAdKrbtgtPasswordLastSet'
        'Test-MtAdTrustTotalCount'
        'Test-MtAdTrustQuarantinedCount'
        'Test-MtAdTrustStaleCount'
    )
}

Describe 'Merged AD schema, RootDSE, service-account and trust checks' {
    BeforeEach {
        $script:detail = $null
        $script:state = [PSCustomObject]@{
            SchemaObjects = @(
                [PSCustomObject]@{ Name = 'classOne'; DistinguishedName = 'CN=classOne,CN=Schema'; ObjectClass = @('top', 'classSchema'); WhenCreated = [datetime]'2020-01-01'; LdapDisplayName = 'classOne' }
                [PSCustomObject]@{ Name = 'classTwo'; DistinguishedName = 'CN=classTwo,CN=Schema'; ObjectClass = @('top', 'classSchema'); WhenCreated = [datetime]'2022-01-01'; LdapDisplayName = 'classTwo' }
                [PSCustomObject]@{ Name = 'attrOne'; DistinguishedName = 'CN=attrOne,CN=Schema'; ObjectClass = @('top', 'attributeSchema'); WhenCreated = [datetime]'2022-01-01'; LdapDisplayName = 'ms-Mcs-AdmPwd' }
            )
            SchemaContainer = [PSCustomObject]@{ ObjectVersion = 91; DistinguishedName = 'CN=Schema'; WhenCreated = [datetime]'2020-01-01' }
            WindowsLapsInstalled = $false
            RootDSE = [PSCustomObject]@{ SupportedSaslMechanisms = @('GSSAPI', 'DIGEST-MD5') }
            ServiceAccounts = @(
                [PSCustomObject]@{ Name = 'standalone'; ObjectClass = @('top', 'msDS-ManagedServiceAccount') }
                [PSCustomObject]@{ Name = 'group'; ObjectClass = @('top', 'msDS-GroupManagedServiceAccount') }
                [PSCustomObject]@{ Name = 'delegated'; ObjectClass = @('top', 'computer', 'msDS-DelegatedManagedServiceAccount'); DelegatedMsaState = 2 }
            )
            Users = @([PSCustomObject]@{ SamAccountName = 'krbtgt'; PasswordLastSet = (Get-Date).AddDays(-200); Enabled = $false })
            Trusts = @(
                [PSCustomObject]@{ TrustPartner = 'external.example'; Direction = 'Inbound'; TrustTypeName = 'Domain Uplevel'; TrustType = 2; TrustAttributes = 0; LastValidated = $null; Modified = [datetime]'2025-01-01' }
                [PSCustomObject]@{ TrustPartner = 'forest.example'; Direction = 'Outbound'; TrustTypeName = 'Domain Uplevel'; TrustType = 2; TrustAttributes = 8; LastValidated = $null; Modified = [datetime]'2025-01-01' }
            )
        }
        Mock Get-MtADDomainState -ModuleName Maester { $script:state }
        Mock Add-MtTestResultDetail -ModuleName Maester { param($Result, [switch] $Investigate) $script:detail = [PSCustomObject]@{ Text = $Result; Investigate = $Investigate.IsPresent } }
    }

    It 'merges schema creation-year counts with all dated object details' {
        Test-MtAdSchemaModificationYearCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'Creation years \| 2'
        $script:detail.Text | Should -Match '2022 \| 2'
        $script:detail.Text | Should -Match '2020 \| classOne \| CN=classOne'
        $script:detail.Text | Should -Match '2022 \| attrOne \| CN=attrOne'
    }

    It 'merges schema version and all classSchema definitions without listing attributes as classes' {
        Test-MtAdSchemaVersionEntryCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'Schema version \| 91'
        $script:detail.Text | Should -Match 'classSchema definitions \| 2'
        $script:detail.Text | Should -Match 'classOne \| CN=classOne'
        $script:detail.Text | Should -Match 'classTwo \| CN=classTwo'
        $script:detail.Text | Should -Not -Match '\| attrOne \| CN=attrOne'
    }

    It 'requires a complete schema pair rather than a solitary legacy password attribute' {
        Test-MtAdLapsInstalledStatus | Should -BeFalse
        $script:detail.Text | Should -Match 'Neither Windows LAPS nor legacy Microsoft LAPS has a complete schema pair'
        $script:state.WindowsLapsInstalled = $true
        $script:state.SchemaObjects += [PSCustomObject]@{ Name = 'ms-LAPS-Password'; LdapDisplayName = 'msLAPS-Password' }
        $script:state.SchemaObjects += [PSCustomObject]@{ Name = 'ms-LAPS-PasswordExpirationTime'; LdapDisplayName = 'msLAPS-PasswordExpirationTime' }
        Test-MtAdLapsInstalledStatus | Should -BeTrue
        $script:detail.Text | Should -Match 'At least one complete LAPS schema pair is present'
    }

    It 'retains legacy Microsoft LAPS readiness without claiming Windows LAPS deployment' {
        $script:state.SchemaObjects += [PSCustomObject]@{ LdapDisplayName = 'ms-Mcs-AdmPwdExpirationTime' }
        Test-MtAdLapsInstalledStatus | Should -BeTrue
        $script:detail.Text | Should -Match 'Legacy Microsoft LAPS schema pair complete \| True'
        $script:detail.Text | Should -Match 'Windows LAPS schema pair complete \| False'
        $script:detail.Text | Should -Match 'not proof that passwords are managed or rotating'
    }

    It 'shows DIGEST-MD5 as advertised, not as a successful authentication' {
        Test-MtAdSupportedSaslMechanismCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'Mechanisms Count \| 2'
        $script:detail.Text | Should -Match 'DIGEST-MD5 \| Digest; advertised'
        $script:detail.Text | Should -Match 'does not establish whether a bind succeeds'
    }

    It 'counts standalone, group and delegated MSAs without double counting' {
        Test-MtAdManagedServiceAccountCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'Total Managed Service Accounts \| 3'
        $script:detail.Text | Should -Match 'gMSA\) \| 1'
        $script:detail.Text | Should -Match 'dMSA\) \| 1'
        $script:detail.Text | Should -Match 'Standalone Managed Service Accounts \| 1'
        $script:detail.Text | Should -Match 'delegated \| dMSA \| 2'
    }

    It 'reports a missing KRBTGT account as unavailable and respects a configured password-age threshold' {
        Test-MtAdKrbtgtPasswordLastSet | Should -BeFalse
        Test-MtAdKrbtgtPasswordLastSet -MaxPasswordAgeDays 240 | Should -BeTrue
        $script:state.Users = @()
        Test-MtAdKrbtgtPasswordLastSet | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Error' }
        $script:detail.Text | Should -Match 'KRBTGT was not found in the visible user inventory'
    }

    It 'merges trust count and all configuration details as investigation' {
        Test-MtAdTrustTotalCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'Total Trusts \| 2'
        $script:detail.Text | Should -Match 'external.example \| Inbound \| Domain Uplevel'
        $script:detail.Text | Should -Match 'forest.example \| Outbound \| Domain Uplevel'
    }

    It 'fails weak SID filtering and lists each finding in the count check' {
        Test-MtAdTrustQuarantinedCount | Should -BeFalse
        $script:detail.Text | Should -Match 'Weak SID Filtering \| 1'
        $script:detail.Text | Should -Match 'external.example \| Inbound \| Domain Uplevel \| External trust:'
        $script:state.Trusts[0].TrustAttributes = 4
        Test-MtAdTrustQuarantinedCount | Should -BeTrue
    }

    It 'investigates unknown trust validation without claiming no stale trusts' {
        Test-MtAdTrustStaleCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'Unknown Validation Status \| 2'
        $script:detail.Text | Should -Match 'external.example \| Inbound \| Domain Uplevel \| Unknown'
        $script:detail.Text | Should -Match 'forest.example \| Outbound \| Domain Uplevel \| Unknown'
        $script:detail.Text | Should -Match 'no stale-trust assertion can be made'
        $script:detail.Text | Should -Not -Match 'No stale trusts detected'
        $script:state.Trusts[0] | Add-Member -NotePropertyName LastValidated -NotePropertyValue (Get-Date).AddDays(-90) -Force
        Test-MtAdTrustStaleCount -StaleThresholdDays 60 | Should -BeTrue
        $script:detail.Text | Should -Match 'Stale Trusts \(>60 days\) \| 1'
        $script:detail.Text | Should -Match 'Unknown Validation Status \| 1'
        $script:detail.Text | Should -Match 'external.example \| Inbound \| Domain Uplevel \| [0-9]{4}-'
    }
}
