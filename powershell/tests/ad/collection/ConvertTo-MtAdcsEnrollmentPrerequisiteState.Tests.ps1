BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
    . (Join-Path $repoRoot 'powershell/internal/services/ad/ConvertTo-MtAdcsEnrollmentPrerequisiteState.ps1')
    function ConvertFrom-MtLdapValue { param($Value) return $Value }
}

Describe 'ConvertTo-MtAdcsEnrollmentPrerequisiteState' {
    It 'returns inconclusive when configuration evidence is unavailable' {
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $null
        $result.EvidenceAvailable | Should -BeFalse
        $result.Disposition | Should -Be 'Inconclusive'
    }

    It 'correlates publication and template prerequisites' {
        $configuration = [PSCustomObject]@{
            EnterpriseCAs = @([PSCustomObject]@{ Name='CA01'; certificateTemplates=@('UserAuth') })
            CertificateTemplates = @([PSCustomObject]@{
                Name='UserAuth'
                'pKIExtendedKeyUsage'=@('1.3.6.1.5.5.7.3.2')
                'msPKI-Enrollment-Flag'=0
                'msPKI-Certificate-Name-Flag'=1
                nTSecurityDescriptor=[PSCustomObject]@{}
            })
        }
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $configuration
        $result.PotentiallyEligibleCount | Should -Be 1
        $result.Templates[0].PublishedBy | Should -Contain 'CA01'
    }

    It 'does not classify an unpublished template as potentially eligible' {
        $configuration = [PSCustomObject]@{
            EnterpriseCAs = @()
            CertificateTemplates = @([PSCustomObject]@{
                Name='Unpublished'
                'pKIExtendedKeyUsage'=@('1.3.6.1.5.5.7.3.2')
                'msPKI-Enrollment-Flag'=0
                'msPKI-Certificate-Name-Flag'=1
                nTSecurityDescriptor=[PSCustomObject]@{}
            })
        }
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $configuration
        $result.Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }

    It 'does not classify a template requiring manager approval as potentially eligible' {
        $configuration = [PSCustomObject]@{
            EnterpriseCAs = @([PSCustomObject]@{ Name='CA01'; certificateTemplates=@('Approval') })
            CertificateTemplates = @([PSCustomObject]@{
                Name='Approval'
                'pKIExtendedKeyUsage'=@('1.3.6.1.5.5.7.3.2')
                'msPKI-Enrollment-Flag'=2
                'msPKI-Certificate-Name-Flag'=1
                nTSecurityDescriptor=[PSCustomObject]@{}
            })
        }
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $configuration
        $result.Templates[0].ManagerApprovalRequired | Should -BeTrue
        $result.Templates[0].Disposition | Should -Be 'PrerequisitesNotSatisfied'
    }

    It 'keeps missing security descriptor evidence inconclusive' {
        $configuration = [PSCustomObject]@{
            EnterpriseCAs = @([PSCustomObject]@{ Name='CA01'; certificateTemplates=@('UnknownAcl') })
            CertificateTemplates = @([PSCustomObject]@{
                Name='UnknownAcl'
                'pKIExtendedKeyUsage'=@('1.3.6.1.5.5.7.3.2')
                'msPKI-Enrollment-Flag'=0
                'msPKI-Certificate-Name-Flag'=1
                nTSecurityDescriptor=$null
            })
        }
        $result = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $configuration
        $result.Templates[0].Disposition | Should -Be 'Inconclusive'
    }
}