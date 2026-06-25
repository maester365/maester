class DMARCRecord {
    [string]$policy
    [int]$percentage

    DMARCRecord([string]$policy, [int]$percentage) {
        $this.policy = $policy
        $this.percentage = $percentage
    }
}

Describe 'Test-MtDomainsDmarcRecordMaturity' {
    BeforeEach {
        $script:skipCustomReason = $null
        $script:testResultMarkdown = $null
        $script:testSeverity = $null
        $script:testName = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param(
                $Result,
                $Severity,
                $TestName,
                $SkippedBecause,
                $SkippedCustomReason
            )

            $script:testResultMarkdown = $Result
            $script:testSeverity = $Severity
            $script:testName = $TestName
            $script:skipCustomReason = $SkippedCustomReason
        }
    }

    It 'skips cleanly when no verified managed domains are found' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtDomainsDmarcRecordMaturity | Should -Be $null
        $script:skipCustomReason | Should -Be 'No verified and managed domains found in tenant'
    }

    It 'includes failed domain details in the result markdown' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [PSCustomObject]@{
                    id                 = 'contoso.com'
                    isVerified         = $true
                    authenticationType = 'Managed'
                    isInitial          = $false
                }
            )
        }
        Mock -ModuleName Maester Get-MtRegistrableDomain {
            param($DomainName)

            return $DomainName
        }
        Mock -ModuleName Maester Get-MailAuthenticationRecord {
            return [PSCustomObject]@{
                domain      = 'contoso.com'
                dmarcRecord = [DMARCRecord]::new('none', 100)
            }
        }

        Test-MtDomainsDmarcRecordMaturity -TestName 'MT.1182: DMARC maturity test' | Should -BeFalse

        $script:testResultMarkdown | Should -Match 'Some tenant domains do not have mature DMARC records'
        $script:testResultMarkdown | Should -Match 'contoso\.com'
        $script:testResultMarkdown | Should -Match 'Medium'
        $script:testResultMarkdown | Should -Match 'none'
        $script:testResultMarkdown | Should -Match '100'
        $script:testResultMarkdown | Should -Match 'Policy is none'
        $script:testSeverity | Should -Be 'Medium'
        $script:testName | Should -Be 'MT.1182: DMARC maturity test'
    }
}
