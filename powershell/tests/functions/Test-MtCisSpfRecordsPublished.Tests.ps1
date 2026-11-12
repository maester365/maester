Describe 'CIS M365 SPF check' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisSpfRecordsPublished

        Mock Get-MtExo -ModuleName Maester {
            if ($Request -eq 'AcceptedDomain') { return $script:domains }
            return @()
        }
        Mock ConvertFrom-MailAuthenticationRecordSpf -ModuleName Maester { $script:spfResults[$DomainName] }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            $script:resultDetail = [pscustomobject]@{
                Result         = $Result
                Investigate    = [bool]$Investigate
                SkippedBecause = $SkippedBecause
            }
        }
    }

    BeforeEach {
        $script:domains = @([pscustomobject]@{ DomainName = 'example.com'; InitialDomain = $false; IsCoExistenceDomain = $false })
        $script:spfResults = @{}
        $script:resultDetail = $null
    }

    It 'requires a hard-fail SPF record for a parked domain' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 ~all' }

        Test-MtCisSpfRecordsPublished -ParkedDomains 'example.com' | Should -BeFalse
        $script:resultDetail.Result | Should -Match 'CIS requires v=spf1 -all'
        $script:resultDetail.Result | Should -Match '\| example\.com \| Parked \|'
    }

    It 'accepts <Record> for a parked domain' -ForEach @(
        @{ Record = 'v=spf1 -all' }
        @{ Record = 'V=SPF1   -ALL ' }
        @{ Record = 'v=spf1 exp=why.example.com -all' }
        @{ Record = 'v=spf1 exp=explain._spf.%{d} -all' }
        @{ Record = 'v=spf1 exp=%{ir}.%{v}.%{d2r-}.example.com -all' }
        @{ Record = 'V=SPF1 EXP=%{S}.%{L1R+}.example.com. -ALL' }
        @{ Record = 'v=spf1 exp=why%%.%_.%-.example.com -all' }
        @{ Record = 'v=spf1 exp=why.example.xn--p1ai -all' }
    ) {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = $Record }

        Test-MtCisSpfRecordsPublished -ParkedDomains 'Example.com.' | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
    }

    It 'rejects <Record> for a parked domain' -ForEach @(
        @{ Record = 'v=spf1 include:spf.protection.outlook.com -all' }
        @{ Record = 'v=spf1 redirect=_spf.example.net' }
        @{ Record = 'v=spf1 -all exp=why.example.com' }
        @{ Record = 'v=spf1 exp=a.example exp=b.example -all' }
        @{ Record = 'v=spf1 exp=%(d).example.com -all' }
        @{ Record = 'v=spf1 exp=%{d.example.com -all' }
        @{ Record = 'v=spf1 exp=%{x}.example.com -all' }
        @{ Record = 'v=spf1 exp=%{d2rr}.example.com -all' }
        @{ Record = 'v=spf1 exp=%{d:}.example.com -all' }
        @{ Record = 'v=spf1 exp=why%.example.com -all' }
        @{ Record = 'v=spf1 exp=%{c}.example.com -all' }
        @{ Record = 'v=spf1 exp=why.example.123 -all' }
        @{ Record = 'v=spf1 exp=why.example.com- -all' }
        @{ Record = 'v=spf1 exp= -all' }
        @{ Record = 'v=spf10 exp=%{d} -all' }
        @{ Record = 'v=spf1 exp=%{d} ~all' }
    ) {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = $Record }
        $script:spfResults['_spf.example.net'] = [pscustomobject]@{ record = 'v=spf1 -all' }

        Test-MtCisSpfRecordsPublished -ParkedDomains 'example.com' | Should -BeFalse
    }

    It 'fails a parked redirect without resolving an unavailable target' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 redirect=_spf.example.net' }
        $script:spfResults['_spf.example.net'] = 'DNS lookup unavailable'

        Test-MtCisSpfRecordsPublished -ParkedDomains 'example.com' | Should -BeFalse
        Should -Invoke ConvertFrom-MailAuthenticationRecordSpf -ModuleName Maester -Times 1 -Exactly
    }

    It 'applies the sending-domain rule to a domain that is not listed' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 ~all' }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
        $script:resultDetail.Investigate | Should -BeFalse
        $script:resultDetail.Result | Should -Match '\| example\.com \| Sending \|'
    }

    It 'binds ParkedDomains from <Source>' -ForEach @(
        @{ Source = 'Setting'; Config = @{}; Classification = 'Parked'; ExpectedResult = $false }
        @{ Source = 'Config'; Config = @{ ParkedDomains = @() }; Classification = 'Sending'; ExpectedResult = $true }
    ) {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 ~all' }
        $binding = InModuleScope Maester -Parameters @{ Config = $Config } {
            ConvertTo-MtTestParameter -Test (Get-MtTest 'CIS.M365.2.1.8') -ConfigValue $Config -GlobalSetting @{ ParkedDomains = @('example.com') }
        }
        $binding.Error | Should -BeNullOrEmpty
        ($binding.Effective | Where-Object Name -EQ 'ParkedDomains').Source | Should -Be $Source
        $parameters = $binding.Bound

        Test-MtCisSpfRecordsPublished @parameters | Should -Be $ExpectedResult
        $script:resultDetail.Result | Should -Match "\| example\.com \| $Classification \|"
    }

    It 'keeps the soft-fail rule for sending domains' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 include:spf.example.net ~all' }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
        $script:resultDetail.Result | Should -Match 'Well done\. All custom domains meet'
    }

    It 'requires the all qualifier to be the final sending-domain term' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 include:spf.example.net -all include:vendor.example' }

        Test-MtCisSpfRecordsPublished | Should -BeFalse
    }

    It 'rejects a sending-domain record with an earlier all mechanism' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 all include:vendor.example -all' }

        Test-MtCisSpfRecordsPublished | Should -BeFalse
    }

    It 'follows a redirect for a sending domain' {
        $script:spfResults['example.com'] = [pscustomobject]@{ record = 'v=spf1 redirect=_spf.example.net' }
        $script:spfResults['_spf.example.net'] = [pscustomobject]@{ record = 'v=spf1 include:spf.protection.outlook.com -all' }

        Test-MtCisSpfRecordsPublished | Should -BeTrue
    }

    It 'returns <Outcome> when another SPF lookup is unavailable' -ForEach @(
        @{ Outcome = 'a failure'; Record = 'v=spf1 ?all'; ExpectedResult = $false; ExpectedSkip = $null }
        @{ Outcome = 'NotSupported'; Record = 'v=spf1 ~all'; ExpectedResult = $null; ExpectedSkip = 'NotSupported' }
    ) {
        $script:domains += [pscustomobject]@{ DomainName = 'unavailable.example'; InitialDomain = $false; IsCoExistenceDomain = $false }
        $script:spfResults['example.com'] = [pscustomobject]@{ record = $Record }
        $script:spfResults['unavailable.example'] = 'DNS lookup unavailable'

        Test-MtCisSpfRecordsPublished | Should -Be $ExpectedResult
        $script:resultDetail.SkippedBecause | Should -Be $ExpectedSkip
        if ($null -eq $ExpectedSkip) {
            $script:resultDetail.Result | Should -Match '\| unavailable\.example .* \| Not checked \|'
        }
    }
}
