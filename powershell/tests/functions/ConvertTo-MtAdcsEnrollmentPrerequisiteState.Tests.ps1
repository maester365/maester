BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    . "$repoRoot/powershell/internal/services/ad/protocol/ConvertFrom-MtLdapValue.ps1"
    . "$repoRoot/powershell/internal/services/ad/ConvertTo-MtAdcsEnrollmentPrerequisiteState.ps1"
    function Get-AdcsTestConfiguration {
        $template = [pscustomobject]@{
            Name = 'UserAuth'
            pKIExtendedKeyUsage = @('1.3.6.1.5.5.7.3.2')
            'msPKI-Enrollment-Flag' = 0
            'msPKI-Certificate-Name-Flag' = 1
            'msPKI-RA-Signature' = 0
            nTSecurityDescriptor = [pscustomobject]@{ Dacl = @(); Owner = 'S-1-5-18' }
        }
        [pscustomobject]@{
            EnterpriseCAs = @([pscustomobject]@{ Name = 'CA01'; certificateTemplates = @('UserAuth') })
            CertificateTemplates = @($template)
        }
    }
}

Describe 'Published AD CS enrollment prerequisite evidence' {
    It 'keeps unavailable configuration inconclusive' {
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $null
        $result.EvidenceAvailable | Should -BeFalse
        $result.PSObject.Properties.Name | Should -Not -Contain 'EligibleCount'
        $result.Disposition | Should -Be 'Inconclusive'
    }
    It 'correlates a published authentication template without claiming exploitability' {
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState (Get-AdcsTestConfiguration)
        $result.PotentiallyEligibleCount | Should -Be 1
        $result.PSObject.Properties.Name | Should -Not -Contain 'EligibleCount'
        $result.Templates[0].PublishedBy | Should -Contain 'CA01'
    }
    It 'does not classify an unpublished template as potentially eligible' {
        $config = Get-AdcsTestConfiguration
        $config.EnterpriseCAs = @()
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
        $result.Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }
    It 'recognizes manager approval as a disproven modeled prerequisite' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].'msPKI-Enrollment-Flag' = 2
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }
    It 'does not treat unavailable security descriptors as authorization evidence' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].nTSecurityDescriptor = $null
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'Inconclusive'
    }
    It 'recognizes required authorization signatures as a separate issuance gate' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].'msPKI-RA-Signature' = 1
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
        $result.Templates[0].AuthorizedSignaturesRequired | Should -Be 1
        $result.Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }
    It 'does not infer a missing signature count to be zero' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].PSObject.Properties.Remove('msPKI-RA-Signature')
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'Inconclusive'
    }
    It 'does not infer an unobserved subject-supply flag to be false' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].PSObject.Properties.Remove('msPKI-Certificate-Name-Flag')
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
        $result.Templates[0].Disposition | Should -Be 'Inconclusive'
        $result.Templates[0].EnrolleeSuppliesSubject | Should -BeNullOrEmpty
    }
    It 'does not infer an unobserved enrollment flag to permit issuance' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].PSObject.Properties.Remove('msPKI-Enrollment-Flag')
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'Inconclusive'
    }
    It 'recognizes an explicitly observed empty EKU as unrestricted' {
        foreach ($empty in @($null, @())) {
            $config = Get-AdcsTestConfiguration
            $config.CertificateTemplates[0].pKIExtendedKeyUsage = $empty
            $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
            $result.Templates[0].AuthenticationCapable | Should -BeTrue
            $result.Templates[0].Disposition | Should -Be 'PotentiallyEligible'
        }
    }
    It 'keeps an uncollected EKU property unknown' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].PSObject.Properties.Remove('pKIExtendedKeyUsage')
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'Inconclusive'
    }
    It 'keeps malformed EKU OID <_> inconclusive' -ForEach @('0.40.1', '1.40.1', '3.1.1', '1.03.6.1', '2.01.1', '1.3.06.1', "1.3.6`n", '1.3.٦') {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].pKIExtendedKeyUsage = @($_)
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
        $result.Templates[0].AuthenticationCapable | Should -BeNullOrEmpty
        $result.Templates[0].Disposition | Should -Be 'Inconclusive'
        $result.Templates[0].MissingEvidence | Should -Contain 'Authentication EKU evidence is unavailable or malformed.'
    }
    It 'accepts valid non-authentication EKU OID <_>' -ForEach @('0.39.1', '1.39.1', '2.40.1', '2.999.1') {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].pKIExtendedKeyUsage = @($_)
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
        $result.Templates[0].AuthenticationCapable | Should -BeFalse
        $result.Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
        $result.Templates[0].MissingEvidence | Should -BeNullOrEmpty
    }
    It 'keeps a malformed EKU unknown alongside a recognized authentication EKU' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].pKIExtendedKeyUsage += '1.40.1'
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'Inconclusive'
    }
    It 'retains an independently known issuance gate despite a malformed EKU' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].pKIExtendedKeyUsage = @('1.40.1')
        $config.CertificateTemplates[0].'msPKI-RA-Signature' = 1
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }
    It 'preserves a CA publication reference that has no matching template' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates = @()
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState $config
        $result.Templates.Count | Should -Be 1
        $result.Templates[0].Name | Should -Be 'UserAuth'
        $result.Templates[0].Disposition | Should -Be 'Inconclusive'
        $result.InconclusiveCount | Should -Be 1
    }
    It 'does not resolve duplicate template CNs by silently selecting one' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates += $config.CertificateTemplates[0].PSObject.Copy()
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).InconclusiveCount | Should -BeGreaterThan 0
    }
    It 'does not let missing evidence override an independently disproven condition' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].'msPKI-Enrollment-Flag' = 2
        $config.CertificateTemplates[0].PSObject.Properties.Remove('msPKI-Certificate-Name-Flag')
        $config.CertificateTemplates[0].PSObject.Properties.Remove('msPKI-RA-Signature')
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }
    It 'uses the real LDAP converter for byte-backed flag and signature values' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates[0].'msPKI-Certificate-Name-Flag' = [Text.Encoding]::UTF8.GetBytes('1')
        $config.CertificateTemplates[0].'msPKI-Enrollment-Flag' = [Text.Encoding]::UTF8.GetBytes('0')
        $config.CertificateTemplates[0].'msPKI-RA-Signature' = [Text.Encoding]::UTF8.GetBytes('1')
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }
    It 'treats malformed, negative or multivalued signature evidence as unknown' {
        foreach ($bad in @('invalid', -1, @('0', '1'))) {
            $config = Get-AdcsTestConfiguration
            $config.CertificateTemplates[0].'msPKI-RA-Signature' = $bad
            (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Templates[0].Disposition | Should -Be 'Inconclusive'
        }
    }
    It 'does not report complete evidence when a CA publication list was not collected' {
        $config = Get-AdcsTestConfiguration
        $config.EnterpriseCAs[0].PSObject.Properties.Remove('certificateTemplates')
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).Disposition | Should -Be 'Inconclusive'
    }
    It 'keeps an unavailable inventory distinct from a completed empty inventory' {
        $config = Get-AdcsTestConfiguration
        $config.CertificateTemplates = $null
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).EvidenceAvailable | Should -BeFalse
        $config.CertificateTemplates = @()
        $config.EnterpriseCAs = @()
        (ConvertTo-MtAdcsEnrollmentPrerequisiteState $config).EvidenceAvailable | Should -BeTrue
    }
}

Describe 'AD-CS-01 native engine outcomes' {
    BeforeAll {
        Import-Module "$repoRoot/powershell/Maester.psd1" -Force -WarningAction SilentlyContinue
        $script:adcsRunConfig = @{ Environment = @{ Services = @{ ActiveDirectory = $true } } }
    }
    BeforeEach {
        $script:adcsConfiguration = Get-AdcsTestConfiguration
        Mock -ModuleName Maester Get-MtADDomainState { [pscustomobject]@{ Configuration = $script:adcsConfiguration } }
    }
    It 'has valid native metadata with an existing resource type and author handle' {
        $test = Get-MtTest AD-CS-01
        $test.IsValid | Should -BeTrue
        $test.Errors | Should -BeNullOrEmpty
        $test.Author | Should -Contain 'rolling-code'
        $test.Contributor | Should -Contain 'FiraSenax'
    }
    It 'reports a known issuance gate as passed' {
        $script:adcsConfiguration.CertificateTemplates[0].'msPKI-RA-Signature' = 1
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Passed'
        $row.ResultDetail.TestResult | Should -BeLike '*Well done*'
    }
    It 'reports configuration candidates as investigation without claiming enrollment success' {
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Investigate'
        $row.ResultDetail.TestResult | Should -BeLike '*UserAuth*PotentiallyEligible*'
        $row.ResultDetail.TestResult | Should -Not -BeLike '*S-1-5-18*'
        $row.ReasonCode | Should -Not -Be 'InvalidReturn'
    }
    It 'shows unknown flag values instead of false in an inconclusive result' {
        $script:adcsConfiguration.CertificateTemplates[0].PSObject.Properties.Remove('msPKI-Certificate-Name-Flag')
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Investigate'
        $row.ResultDetail.TestResult | Should -BeLike '*Unknown*Inconclusive*'
    }
    It 'reports a malformed EKU as investigation through the native engine' {
        $script:adcsConfiguration.CertificateTemplates[0].pKIExtendedKeyUsage = @('1.40.1')
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Investigate'
        $row.ResultDetail.TestResult | Should -BeLike '*Unknown*Inconclusive*'
        $row.ResultDetail.TestResult | Should -BeLike '*Authentication EKU evidence is unavailable or malformed*'
    }
    It 'does not pass an unavailable configuration inventory' {
        $script:adcsConfiguration = $null
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Investigate'
    }
    It 'uses NotApplicable for a completed inventory without published templates' {
        $script:adcsConfiguration.EnterpriseCAs = @()
        $script:adcsConfiguration.CertificateTemplates = @()
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'NotApplicable'
    }
    It 'escapes directory-controlled names without changing table columns or rendering HTML' {
        $name = "Template | <img src=x> `$&`nnext"
        $script:adcsConfiguration.CertificateTemplates[0].Name = $name
        $script:adcsConfiguration.EnterpriseCAs[0].certificateTemplates = @($name)
        $script:adcsConfiguration.EnterpriseCAs[0].Name = 'CA | <b>name</b>'
        $row = Invoke-MtTest -Id AD-CS-01 -Config $script:adcsRunConfig
        $row.Result.ToString() | Should -Be 'Investigate'
        $detail = $row.ResultDetail.TestResult
        $detail | Should -Not -Match '<img|<b>'
        $tableRows = @($detail -split '\r?\n' | Where-Object { $_.StartsWith('| ') })
        $tableRows.Count | Should -Be 3
        foreach ($line in $tableRows) { [regex]::Matches($line, '(?<!\\)\|').Count | Should -Be 10 }
    }
}
