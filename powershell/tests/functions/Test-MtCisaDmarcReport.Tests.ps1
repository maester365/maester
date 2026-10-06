BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue

    # The real DMARCRecord class lives inside ConvertFrom-MailAuthenticationRecordDmarc; the test matches it by name.
    class DMARCRecord {
        [object[]] $reportAggregate
        [object[]] $reportForensic
    }
    function New-DmarcRecord([string[]] $Rua = @(), [string[]] $Ruf = @()) {
        $r = [DMARCRecord]::new()
        $r.reportAggregate = @($Rua | ForEach-Object { [pscustomobject]@{ mailAddress = [mailaddress]$_ } })
        $r.reportForensic = @($Ruf | ForEach-Object { [pscustomobject]@{ mailAddress = [mailaddress]$_ } })
        $r
    }
    function Invoke-Check([object[]] $Domains, [hashtable] $Records) {
        $script:Domains = $Domains
        $script:Records = $Records
        Mock -ModuleName Maester Get-MtExo { $script:Domains } -ParameterFilter { $Request -eq 'AcceptedDomain' }
        Mock -ModuleName Maester Get-MailAuthenticationRecord {
            $value = if ($script:Records.ContainsKey($DomainName)) { $script:Records[$DomainName] } else { 'Record does not exist' }
            [pscustomobject]@{ domain = $DomainName; dmarcRecord = $value }
        }
        $config = [pscustomobject]@{ Environment = [pscustomobject]@{ Services = [pscustomobject]@{ ExchangeOnline = $true } } }
        Invoke-MtTest -Id 'CISA.MS.EXO.4.4' -Config $config
    }
    function New-Domain([string] $Name, [switch] $Initial) {
        [pscustomobject]@{ DomainName = $Name; InitialDomain = [bool]$Initial; IsCoexistenceDomain = $false }
    }
}

Describe 'CISA.MS.EXO.4.4 (Test-MtCisaDmarcReport)' {
    BeforeEach {
        Mock -ModuleName Maester Test-MtConnection { $true }
    }

    It 'Passes when rua has an agency address and ruf has an address' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.com') -Records @{ 'contoso.com' = (New-DmarcRecord -Rua 'reports@dmarc.cyber.dhs.gov', 'dmarc@contoso.com' -Ruf 'dmarc@contoso.com') }
        $row.Result | Should -Be 'Passed'
    }

    It 'Accepts a report address outside the domain' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.com') -Records @{ 'contoso.com' = (New-DmarcRecord -Rua 'contoso@rua.dmarc.example' -Ruf 'contoso@ruf.dmarc.example') }
        $row.Result | Should -Be 'Passed'
    }

    It 'Fails when the only aggregate address is CISA''s' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.com') -Records @{ 'contoso.com' = (New-DmarcRecord -Rua 'reports@dmarc.cyber.dhs.gov' -Ruf 'dmarc@contoso.com') }
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -BeLike '*No agency point of contact for aggregate reports (rua)*'
    }

    It 'Fails when there is no failure report address' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.com') -Records @{ 'contoso.com' = (New-DmarcRecord -Rua 'dmarc@contoso.com') }
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -BeLike '*failure reports (ruf)*'
    }

    It 'Fails when a domain has no DMARC record' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.com') -Records @{}
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -BeLike '*No DMARC record*'
    }

    It 'Uses the organizational domain''s record for a subdomain under a multi-label suffix' {
        $row = Invoke-Check -Domains (New-Domain 'mail.contoso.co.uk') -Records @{ 'contoso.co.uk' = (New-DmarcRecord -Rua 'dmarc@contoso.co.uk' -Ruf 'dmarc@contoso.co.uk') }
        $row.Result | Should -Be 'Passed'
        $row.ResultDetail.TestResult | Should -BeLike '*_dmarc.contoso.co.uk*'
    }

    It 'Skips Microsoft-managed domains' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.onmicrosoft.com' -Initial) -Records @{}
        $row.Result | Should -Be 'Skipped'
        $row.ResultDetail.TestSkipped | Should -Be 'NotApplicable'
    }

    It 'Is skipped as NotSupported when DNS lookups are not available' {
        $row = Invoke-Check -Domains (New-Domain 'contoso.com') -Records @{ 'contoso.com' = 'Unsupported platform, Resolve-DnsName not available' }
        $row.Result | Should -Be 'Skipped'
        $row.ResultDetail.TestSkipped | Should -Be 'NotSupported'
    }
}
