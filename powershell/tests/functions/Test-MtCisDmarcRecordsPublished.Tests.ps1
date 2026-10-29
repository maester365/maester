Describe 'CIS M365 DMARC check' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisDmarcRecordsPublished

        $script:domains = @()
        $script:registrableDomains = @{}
        $script:dmarcResults = @{}

        Mock Get-MtExo -ModuleName Maester { $script:domains }
        Mock Get-MtRegistrableDomain -ModuleName Maester { $script:registrableDomains[$DomainName] }
        Mock ConvertFrom-MailAuthenticationRecordDmarc -ModuleName Maester { $script:dmarcResults[$DomainName] }
        Mock Add-MtTestResultDetail -ModuleName Maester {}
    }

    BeforeEach {
        $script:domains = @()
        $script:registrableDomains = @{}
        $script:dmarcResults = @{}
    }

    It 'fails a known noncompliant domain before skipping an unavailable lookup' {
        $script:domains = @(
            [pscustomobject]@{ DomainName = 'bad.example'; IsCoExistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'unavailable.example'; IsCoExistenceDomain = $false }
        )
        $script:registrableDomains = @{
            'bad.example'         = 'bad.example'
            'unavailable.example' = 'unavailable.example'
        }
        $script:dmarcResults = @{
            'bad.example'         = 'Failure to obtain record'
            'unavailable.example' = 'DNS lookup unavailable'
        }

        Test-MtCisDmarcRecordsPublished | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -match '1 domain\(s\) do not have a compliant DMARC policy'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 0 -Exactly -ParameterFilter {
            $SkippedBecause -eq 'NotSupported'
        }
    }

    It 'looks up the organizational domain after an invalid subdomain record and reports an invalid effective record' {
        $script:domains = @([pscustomobject]@{ DomainName = 'mail.example.com'; IsCoExistenceDomain = $false })
        $script:registrableDomains = @{ 'mail.example.com' = 'example.com' }
        $script:dmarcResults = @{
            'mail.example.com' = 'Invalid DMARC record'
            'example.com'      = 'Failure to obtain record'
        }

        Test-MtCisDmarcRecordsPublished | Should -BeFalse
        Should -Invoke ConvertFrom-MailAuthenticationRecordDmarc -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $DomainName -eq 'example.com'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -match 'Invalid DMARC record' -and $Result -match 'mail.example.com'
        }
    }
}