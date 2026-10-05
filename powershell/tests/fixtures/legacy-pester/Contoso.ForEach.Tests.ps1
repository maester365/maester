# Legacy Pester fixture: BeforeDiscovery builds data, -ForEach and -TestCases expand it.
# The ID of each instance is built at discovery time, so 3.0 can select it as a family only.
BeforeDiscovery {
    $apps = @(
        @{ Name = 'Payroll'; Id = 'app1'; HasOwner = $true }
        @{ Name = 'Intranet'; Id = 'app2'; HasOwner = $false }
    )
}

Describe "Contoso applications" -Tag "Contoso", "Apps" {
    It "CONTOSO.2001.<Id>: Application <Name> has an owner" -Tag "CONTOSO.2001" -ForEach $apps {
        $HasOwner | Should -BeTrue -Because "$Name needs an owner"
    }

    It "CONTOSO.2002: Application <Name> has a name" -Tag "CONTOSO.2002" -TestCases $apps {
        $Name | Should -Not -BeNullOrEmpty
    }
}

Describe "Contoso per-region <_>" -Tag "Contoso" -ForEach @('EU', 'US') {
    It "CONTOSO.2003: Region <_> is configured" {
        $_ | Should -BeIn @('EU', 'US')
    }
}
