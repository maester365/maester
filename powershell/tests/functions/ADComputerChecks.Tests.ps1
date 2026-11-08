Describe 'Active Directory computer inventory checks' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name @(
            'Test-MtAdComputerUnconstrainedDelegationCount'
            'Test-MtAdComputerNonDcConstrainedDelegationCount'
            'Test-MtAdComputerOperatingSystemCount'
            'Test-MtAdComputerPerOUAverage'
            'Test-MtAdComputerCreatorSidCount'
            'Test-MtAdComputerInDefaultContainer'
            'Test-MtAdComputerNonStandardGroup'
        )
    }

    BeforeEach {
        $script:Details = $null
        $script:AdComputerState = [PSCustomObject]@{
            Computers = @(
                [PSCustomObject]@{ Name = 'dc1'; DistinguishedName = 'CN=dc1,OU=Domain Controllers,DC=example,DC=com'; DnsHostName = 'dc1.example.com'; PrimaryGroupId = 516; Enabled = $true; TrustedForDelegation = $true; TrustedToAuthForDelegation = $false; AllowedToDelegateTo = @(); HasResourceBasedConstrainedDelegation = $false; OperatingSystem = 'Server' }
                [PSCustomObject]@{ Name = 'app|one'; DistinguishedName = 'CN=app\,one,OU=Servers|Prod,DC=example,DC=com'; DnsHostName = 'app.example.com'; PrimaryGroupId = 515; Enabled = $true; TrustedForDelegation = $false; TrustedToAuthForDelegation = $true; AllowedToDelegateTo = @('HTTP/backend|one'); HasResourceBasedConstrainedDelegation = $true; OperatingSystem = '' }
                [PSCustomObject]@{ Name = 'client'; DistinguishedName = 'CN=client,OU=Clients,DC=example,DC=com'; DnsHostName = 'client.example.com'; PrimaryGroupId = 515; Enabled = $true; TrustedForDelegation = $false; TrustedToAuthForDelegation = $false; AllowedToDelegateTo = @(); HasResourceBasedConstrainedDelegation = $false; OperatingSystem = 'Client' }
            )
            DomainControllers = @([PSCustomObject]@{ Name = 'dc1'; ServerReference = 'CN=dc1,OU=Domain Controllers,DC=example,DC=com'; DnsHostName = 'dc1.example.com' })
            ServiceAccounts = @()
        }
        Mock -ModuleName Maester Get-MtADDomainState { $script:AdComputerState }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result, [switch] $Investigate) $script:Details = [PSCustomObject]@{ Text = $Result; Investigate = $Investigate.IsPresent } }
    }

    It 'excludes DCs and uses only non-DC computers as the unconstrained percentage denominator' {
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Percentage with Unconstrained Delegation | 0% |*'

        $script:AdComputerState.Computers[1].TrustedForDelegation = $true
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| Non-DC Percentage with Unconstrained Delegation | 50% |*'
        $script:Details.Text | Should -Match 'app\\\|one'
    }

    It 'inventories classic KCD, protocol transition, and RBCD descriptor presence independently' {
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Classic KCD Target SPNs | 1 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Protocol Transition Flag | 1 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with RBCD Descriptor Present | 1 |*'
        $script:Details.Text | Should -BeLike '*| Distinct Non-DC Accounts with One or More Indicators | 1 |*'
        $script:Details.Text | Should -Match 'HTTP/backend\\\|one'

        $script:AdComputerState.Computers[1].TrustedToAuthForDelegation = $false
        $script:AdComputerState.Computers[2].HasResourceBasedConstrainedDelegation = $true
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Classic KCD Target SPNs | 1 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Protocol Transition Flag | 0 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with RBCD Descriptor Present | 2 |*'
        $script:Details.Text | Should -BeLike '*| Distinct Non-DC Accounts with One or More Indicators | 2 |*'
    }

    It 'does not treat missing delegation metadata as a clean result' {
        $script:AdComputerState.Computers[1].PSObject.Properties.Remove('AllowedToDelegateTo')
        { Test-MtAdComputerNonDcConstrainedDelegationCount } | Should -Throw '*Required delegation fields*'
        $script:AdComputerState.Computers[1].TrustedForDelegation = $null
        { Test-MtAdComputerUnconstrainedDelegationCount } | Should -Throw '*flag is missing*'
    }

    It 'does not treat unknown RBCD descriptor presence as false' {
        $script:AdComputerState.Computers[1].HasResourceBasedConstrainedDelegation = $null
        { Test-MtAdComputerNonDcConstrainedDelegationCount } | Should -Throw '*Required delegation fields*'
    }

    It 'excludes RODCs by server inventory and DCs by DNS fallback, not a claimed primary group' {
        $script:AdComputerState.Computers += [PSCustomObject]@{ Name = 'rodc-other'; DistinguishedName = 'CN=rodc-other,DC=example,DC=com'; DnsHostName = 'rodc-other.example.com'; PrimaryGroupId = 521; TrustedForDelegation = $true; TrustedToAuthForDelegation = $true; AllowedToDelegateTo = @('HTTP/dc'); HasResourceBasedConstrainedDelegation = $true }
        $script:AdComputerState.Computers += [PSCustomObject]@{ Name = 'dc-alias'; DistinguishedName = 'CN=dc-alias,DC=example,DC=com'; DnsHostName = 'SECOND.example.com'; PrimaryGroupId = 515; TrustedForDelegation = $true; TrustedToAuthForDelegation = $true; AllowedToDelegateTo = @('HTTP/dc'); HasResourceBasedConstrainedDelegation = $true }
        $script:AdComputerState.DomainControllers += [PSCustomObject]@{ Name = 'different-short-name'; ServerReference = ''; DnsHostName = 'second.EXAMPLE.com' }
        $script:AdComputerState.DomainControllers += [PSCustomObject]@{ Name = 'rodc-other'; ServerReference = 'CN=rodc-other,DC=example,DC=com'; DnsHostName = 'rodc-other.example.com' }

        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
    }

    It 'counts unknown operating systems without suggesting OS support or patch status' {
        Test-MtAdComputerOperatingSystemCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Computers with Unknown OS | 1 |*'
        $script:Details.Text | Should -BeLike '*| Unknown OS | 1 | 33.33% of all computers |*'
    }

    It 'escapes container cells and supplies a heading for the top five table' {
        Test-MtAdComputerPerOUAverage | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -Match '\| Container \| Computer Count \|'
        $script:Details.Text | Should -Match 'OU=Servers\\\|Prod'
    }

    It 'does not report missing CreatorSid collection as zero CreatorSids' {
        Test-MtAdComputerCreatorSidCount | Should -BeFalse
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*CreatorSid is not collected*'
    }

    It 'fails when an enabled computer is a child of the default Computers container' {
        $script:AdComputerState.Computers[2].DistinguishedName = 'CN=client,CN=Computers,DC=example,DC=com'
        Test-MtAdComputerInDefaultContainer | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| In Default Computers Container | 1 |*'
    }

    It 'counts optional CreatorSid metadata rather than treating its presence as a security failure' {
        foreach ($computer in $script:AdComputerState.Computers) {
            $computer | Add-Member -NotePropertyName CreatorSid -NotePropertyValue $null
        }
        $script:AdComputerState.Computers[1].CreatorSid = 'S-1-5-21-1-2-3-1100'
        Test-MtAdComputerCreatorSidCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Computers with CreatorSid | 1 |*'
    }

    It 'recognizes escaped commas in the computer name without counting an OU named Computers' {
        $script:AdComputerState.Computers[1].DistinguishedName = 'CN=app\,one,CN=Computers,DC=example,DC=com'
        $script:AdComputerState.Computers[2].DistinguishedName = 'CN=client,OU=Computers,DC=example,DC=com'
        Test-MtAdComputerInDefaultContainer | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| In Default Computers Container | 1 |*'
    }

    It 'does not exclude a non-DC account claiming primary group <Group>' -ForEach @(@{ Group = 516 }, @{ Group = 521 }) {
        $script:AdComputerState.Computers[2].PrimaryGroupId = $Group
        $script:AdComputerState.Computers[2].TrustedForDelegation = $true
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Computers Claiming DC Primary Groups | 1 |*'
        Test-MtAdComputerNonStandardGroup | Should -BeFalse
        $script:Details.Text | Should -Match 'client'
    }

    It 'does not accept a forged DNS name when the DC inventory has serverReference' {
        $script:AdComputerState.Computers[2].DnsHostName = 'dc1.example.com'
        $script:AdComputerState.Computers[2].TrustedForDelegation = $true
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
    }

    It 'includes delegation on <Class> without adding it to device percentages' -ForEach @(
        @{ Class = 'msDS-ManagedServiceAccount' }
        @{ Class = 'msDS-GroupManagedServiceAccount' }
        @{ Class = 'msDS-DelegatedManagedServiceAccount' }
    ) {
        $script:AdComputerState.ServiceAccounts = @([PSCustomObject]@{
                Name = 'Managed service'; DistinguishedName = 'CN=Managed,DC=example,DC=com'
                ObjectClass = @('computer', $Class); TrustedForDelegation = $true
                TrustedToAuthForDelegation = $true; AllowedToDelegateTo = @('HTTP/managed')
                HasResourceBasedConstrainedDelegation = $true
            })
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| Managed Service Accounts with Unconstrained Delegation | 1 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Percentage with Unconstrained Delegation | 0% |*'
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Classic KCD Target SPNs | 2 |*'
        $script:Details.Text | Should -Match 'Managed service'
    }

    It 'errors when the managed account inventory or delegation flags are unavailable' {
        $script:AdComputerState.ServiceAccounts = $null
        { Test-MtAdComputerUnconstrainedDelegationCount } | Should -Throw '*inventories*'
        $script:AdComputerState.ServiceAccounts = @([PSCustomObject]@{ Name = 'Unknown'; TrustedForDelegation = $null })
        { Test-MtAdComputerUnconstrainedDelegationCount } | Should -Throw '*flag is missing*'
    }
}
