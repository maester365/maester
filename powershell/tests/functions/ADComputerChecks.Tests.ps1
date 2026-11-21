Describe 'Active Directory computer cleanup regressions' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name @(
            'Test-MtAdComputerUnconstrainedDelegationCount', 'Test-MtAdComputerNonDcConstrainedDelegationCount'
            'Test-MtAdComputerOperatingSystemCount', 'Test-MtAdComputerPerOUAverage', 'Test-MtAdComputerOUCount'
            'Test-MtAdComputerCreatorSidCount', 'Test-MtAdComputerInDefaultContainer', 'Test-MtAdComputerNonStandardGroup'
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
            DomainControllers = @([PSCustomObject]@{ ServerReference = 'CN=dc1,OU=Domain Controllers,DC=example,DC=com'; DnsHostName = 'dc1.example.com' })
            ServiceAccounts = @()
        }
        Mock -ModuleName Maester Get-MtADDomainState { $script:AdComputerState }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result, [switch] $Investigate) $script:Details = [PSCustomObject]@{ Text = $Result; Investigate = $Investigate.IsPresent } }
    }

    It 'fails only for non-DC unconstrained delegation and uses the non-DC denominator' {
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeTrue
        $script:Details.Investigate | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| Non-DC Percentage with Unconstrained Delegation | 0% |*'
        $script:AdComputerState.Computers[1].TrustedForDelegation = $true
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Percentage with Unconstrained Delegation | 50% |*'
        $script:Details.Text | Should -Match 'app\\\|one'
    }

    It 'reports overlapping KCD, protocol-transition and RBCD indicators independently' {
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Distinct Non-DC Accounts with One or More Indicators | 1 |*'
        $script:AdComputerState.Computers[1].TrustedToAuthForDelegation = $false
        $script:AdComputerState.Computers[2].HasResourceBasedConstrainedDelegation = $true
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Classic KCD Target SPNs | 1 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Protocol Transition Flag | 0 |*'
        $script:Details.Text | Should -BeLike '*| Non-DC Accounts with RBCD Descriptor Present | 2 |*'
        $script:Details.Text | Should -BeLike '*| Distinct Non-DC Accounts with One or More Indicators | 2 |*'
        $script:Details.Text | Should -Match 'HTTP/backend\\\|one'
    }

    It 'requires DC inventory evidence, including RODCs and DNS-only inventory entries' {
        $script:AdComputerState.Computers += [PSCustomObject]@{ Name = 'rodc'; DistinguishedName = 'CN=rodc,DC=example,DC=com'; DnsHostName = 'rodc.example.com'; PrimaryGroupId = 521; TrustedForDelegation = $true }
        $script:AdComputerState.Computers += [PSCustomObject]@{ Name = 'dc-alias'; DistinguishedName = 'CN=dc-alias,DC=example,DC=com'; DnsHostName = 'SECOND.example.com'; TrustedForDelegation = $true }
        $script:AdComputerState.DomainControllers += [PSCustomObject]@{ ServerReference = 'CN=rodc,DC=example,DC=com'; DnsHostName = 'rodc.example.com' }
        $script:AdComputerState.DomainControllers += [PSCustomObject]@{ ServerReference = ''; DnsHostName = 'second.EXAMPLE.com' }
        Test-MtAdComputerUnconstrainedDelegationCount | Should -BeTrue
        Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'

        $script:AdComputerState.Computers[2].DnsHostName = 'dc1.example.com'
        $script:AdComputerState.Computers[2].TrustedForDelegation = $true
        foreach ($group in 516, 521) {
            $script:AdComputerState.Computers[2].PrimaryGroupId = $group
            Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
            $script:Details.Text | Should -BeLike '*| Non-DC Computers Claiming DC Primary Groups | 1 |*'
            $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
        }
    }

    It 'assesses managed accounts once without inflating device percentages' {
        foreach ($class in 'msDS-ManagedServiceAccount', 'msDS-GroupManagedServiceAccount', 'msDS-DelegatedManagedServiceAccount') {
            $managed = [PSCustomObject]@{ Name = 'Managed'; DistinguishedName = 'CN=Managed,DC=example,DC=com'; ObjectClass = @('computer', $class); TrustedForDelegation = $true; TrustedToAuthForDelegation = $true; AllowedToDelegateTo = @('HTTP/managed'); HasResourceBasedConstrainedDelegation = $true }
            $script:AdComputerState.ServiceAccounts = @($managed)
            $script:AdComputerState.Computers = @($script:AdComputerState.Computers | Select-Object -First 3) + @($managed)
            Test-MtAdComputerUnconstrainedDelegationCount | Should -BeFalse
            $script:Details.Text | Should -BeLike '*| Managed Service Accounts with Unconstrained Delegation | 1 |*'
            $script:Details.Text | Should -BeLike '*| Non-DC Percentage with Unconstrained Delegation | 0% |*'
            Test-MtAdComputerNonDcConstrainedDelegationCount | Should -BeTrue
            $script:Details.Text | Should -BeLike '*| Total Non-DC Computers | 2 |*'
            $script:Details.Text | Should -BeLike '*| Non-DC Accounts with Classic KCD Target SPNs | 2 |*'
        }
    }

    It 'does not turn missing delegation fields or inventories into clean results' {
        foreach ($field in 'AllowedToDelegateTo', 'TrustedToAuthForDelegation', 'HasResourceBasedConstrainedDelegation') {
            $saved = $script:AdComputerState.Computers[1].$field
            $script:AdComputerState.Computers[1].$field = $null
            { Test-MtAdComputerNonDcConstrainedDelegationCount } | Should -Throw '*Required delegation fields*'
            $script:AdComputerState.Computers[1].$field = $saved
        }
        $script:AdComputerState.Computers[1].PSObject.Properties.Remove('AllowedToDelegateTo')
        { Test-MtAdComputerNonDcConstrainedDelegationCount } | Should -Throw '*Required delegation fields*'
        $script:AdComputerState.Computers[1].TrustedForDelegation = $null
        { Test-MtAdComputerUnconstrainedDelegationCount } | Should -Throw '*flag is missing*'
        $script:AdComputerState.ServiceAccounts = $null
        { Test-MtAdComputerUnconstrainedDelegationCount } | Should -Throw '*inventories*'
        $script:AdComputerState.ServiceAccounts = @([PSCustomObject]@{ TrustedForDelegation = $null })
        { Test-MtAdComputerUnconstrainedDelegationCount } | Should -Throw '*flag is missing*'
    }

    It 'uses all computers for OS percentages and escapes known OS names' {
        $script:AdComputerState.Computers[0].PSObject.Properties.Remove('OperatingSystem')
        $script:AdComputerState.Computers[1].OperatingSystem = "Server|Core`nEdition"
        Test-MtAdComputerOperatingSystemCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Server\|Core Edition | 1 | 33.33% |*'
        $script:Details.Text | Should -BeLike '*| Client | 1 | 33.33% |*'
        $script:Details.Text | Should -BeLike '*| Unknown OS | 1 | 33.33% |*'
    }

    It 'renders an all-undefined OS table and handles an empty inventory' {
        $script:AdComputerState.Computers[0].OperatingSystem = $null
        $script:AdComputerState.Computers[1].OperatingSystem = ''
        $script:AdComputerState.Computers[2].OperatingSystem = " `t "
        Test-MtAdComputerOperatingSystemCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Distinct Operating Systems | 0 |*'
        $script:Details.Text | Should -Match '(?s)\*\*Operating Systems in Use:\*\*\s+\| Operating System \| Count \| Percentage of All Computers \|\s+\| --- \| --- \| --- \|\s+\| Unknown OS \| 3 \| 100% \|'
        $script:AdComputerState.Computers = @()
        Test-MtAdComputerOperatingSystemCount | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Total Computers | 0 |*'
        $script:Details.Text | Should -Not -Match 'Operating Systems in Use|\| Unknown OS \|'
    }

    It 'counts optional CreatorSid data for review without reporting uncollected fields as zero' {
        Test-MtAdComputerCreatorSidCount | Should -BeFalse
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*CreatorSid is not collected*'
        foreach ($computer in $script:AdComputerState.Computers) { $computer | Add-Member -NotePropertyName CreatorSid -NotePropertyValue $null }
        $script:AdComputerState.Computers[1].CreatorSid = 'S-1-5-21-1-2-3-1100'
        Test-MtAdComputerCreatorSidCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Computers with CreatorSid | 1 |*'
    }

    It 'enforces primary groups using verified DC identity, not a claimed group' {
        Test-MtAdComputerNonStandardGroup | Should -BeTrue
        $script:Details.Investigate | Should -BeFalse
        foreach ($group in 516, 521) {
            $script:AdComputerState.Computers[2].PrimaryGroupId = $group
            Test-MtAdComputerNonStandardGroup | Should -BeFalse
            $script:Details.Text | Should -Match 'client'
        }
    }

    It 'distinguishes the default container from an OU and handles escaped computer names' {
        Test-MtAdComputerInDefaultContainer | Should -BeTrue
        $script:Details.Investigate | Should -BeFalse
        $script:AdComputerState.Computers[1].DistinguishedName = 'CN=app\,one,CN=Computers,DC=example,DC=com'
        $script:AdComputerState.Computers[2].DistinguishedName = 'CN=client,OU=Computers,DC=example,DC=com'
        Test-MtAdComputerInDefaultContainer | Should -BeFalse
        $script:Details.Text | Should -BeLike '*| In Default Computers Container | 1 |*'
        $script:AdComputerState.Computers[1].Enabled = $false
        Test-MtAdComputerInDefaultContainer | Should -BeTrue
    }

    It 'groups escaped names under their actual parent and escapes the top-five table' {
        Test-MtAdComputerOUCount | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        Test-MtAdComputerPerOUAverage | Should -BeTrue
        $script:Details.Investigate | Should -BeTrue
        $script:Details.Text | Should -BeLike '*| Container | Computer Count |*'
        $script:Details.Text | Should -BeLike '*| OU=Servers\|Prod,DC=example,DC=com | 1 |*'
    }

    It 'collects delegation and CreatorSid metadata without changing the shared computer population' {
        Mock -ModuleName Maester Invoke-MtLdapSearch -RemoveParameterType Connection {
            [PSCustomObject]@{ name = 'Managed'; objectClass = @('computer', 'msDS-DelegatedManagedServiceAccount'); userAccountControl = 17301504; 'msDS-AllowedToDelegateTo' = @('HTTP/service'); 'msDS-AllowedToActOnBehalfOfOtherIdentity' = [byte[]]@(1, 2, 3) }
        }
        InModuleScope Maester {
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
            try {
                $computer = @(Get-MtLdapComputer -Connection $connection -SearchBase 'DC=example,DC=com')[0]
                $account = @(Get-MtLdapServiceAccount -Connection $connection -SearchBase 'DC=example,DC=com')[0]
                foreach ($object in $computer, $account) {
                    $object.ObjectClass | Should -Contain 'msDS-DelegatedManagedServiceAccount'
                    $object.TrustedForDelegation | Should -BeTrue
                    $object.TrustedToAuthForDelegation | Should -BeTrue
                    $object.AllowedToDelegateTo | Should -Contain 'HTTP/service'
                    $object.HasResourceBasedConstrainedDelegation | Should -BeTrue
                    $object.PSObject.Properties.Name | Should -Not -Contain 'msDS-AllowedToActOnBehalfOfOtherIdentity'
                }
                (ConvertFrom-MtLdapValue -AttributeName 'mS-DS-CreatorSID' -Value ([byte[]]@(1, 1, 0, 0, 0, 0, 0, 5, 11, 0, 0, 0))).Value | Should -Be 'S-1-5-11'
            }
            finally { $connection.Dispose() }
        }
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Filter -eq '(objectClass=computer)' -and $Attributes -contains 'objectClass' -and $Attributes -contains 'mS-DS-CreatorSID' }
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Filter -match 'msDS-ManagedServiceAccount' -and $Filter -match 'msDS-GroupManagedServiceAccount' -and $Filter -match 'msDS-DelegatedManagedServiceAccount' -and
            @($Attributes | Where-Object { $_ -match '^msDS-ManagedPassword' }).Count -eq 0
        }
    }
}
