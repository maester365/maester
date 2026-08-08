BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Keep -Service All tests isolated from optional service modules that may not be installed.
    $script:createdStubs = @()
    foreach ($cmd in 'Get-AzContext','Connect-AzAccount','Connect-ExchangeOnline','Connect-IPPSSession','Get-ConnectionInformation','Connect-MgGraph','Connect-MicrosoftTeams','Get-ADRootDSE') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "function:global:$cmd" -Value { } | Out-Null
            $script:createdStubs += $cmd
        }
    }
}

AfterAll {
    foreach ($cmd in $script:createdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

Describe 'Connect-Maester' {
    It 'Offers GitHub as a -Service option' {
        $serviceParameter = (Get-Command Connect-Maester).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'GitHub'
    }

    It 'Offers ActiveDirectory as a -Service option' {
        $serviceParameter = (Get-Command Connect-Maester).Parameters['Service']
        $validateSet = $serviceParameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1

        $validateSet.ValidValues | Should -Contain 'ActiveDirectory'
    }

    It 'Offers GitHubOrganization as a parameter' {
        (Get-Command Connect-Maester).Parameters.Keys | Should -Contain 'GitHubOrganization'
    }

    It 'Offers ActiveDirectoryServer as a parameter' {
        (Get-Command Connect-Maester).Parameters.Keys | Should -Contain 'ActiveDirectoryServer'
    }

    It 'Accepts multiple ActiveDirectoryServer values' {
        (Get-Command Connect-Maester).Parameters['ActiveDirectoryServer'].ParameterType.FullName | Should -Be 'System.String[]'
    }

    It 'Calls Connect-MtGitHub when -Service GitHub is specified' {
        Mock Connect-MtGitHub -ModuleName Maester {}

        Connect-Maester -Service GitHub

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 1 -Exactly
    }

    It 'Passes -GitHubOrganization to Connect-MtGitHub' {
        Mock Connect-MtGitHub -ModuleName Maester -ParameterFilter { $Organization -eq 'myorg' } {}

        Connect-Maester -Service GitHub -GitHubOrganization 'myorg'

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Organization -eq 'myorg' }
    }

    It 'Validates Active Directory when -Service ActiveDirectory is specified' {
        Mock Get-ADRootDSE -ModuleName Maester {
            [PSCustomObject]@{
                defaultNamingContext       = 'DC=contoso,DC=com'
                configurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                schemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                dnsHostName                = 'dc01.contoso.com'
            }
        }

        Connect-Maester -Service ActiveDirectory

        Should -Invoke Get-ADRootDSE -ModuleName Maester -Times 1 -Exactly
    }

    It 'Passes ActiveDirectoryServer to the AD connectivity probe and records the target' {
        Mock Get-ADRootDSE -ModuleName Maester -ParameterFilter { $Server -eq 'dc02.contoso.com' } {
            [PSCustomObject]@{
                defaultNamingContext       = 'DC=contoso,DC=com'
                configurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                schemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                dnsHostName                = 'dc02.contoso.com'
            }
        }

        Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer 'dc02.contoso.com'

        Should -Invoke Get-ADRootDSE -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Server -eq 'dc02.contoso.com' }
        InModuleScope Maester {
            $__MtSession.ADConnection.TargetServer | Should -Be 'dc02.contoso.com'
        }
    }

    It 'Validates and stores multiple ActiveDirectoryServer targets' {
        Mock Get-ADRootDSE -ModuleName Maester -ParameterFilter { $Server -eq 'dc01.contoso.com' } {
            [PSCustomObject]@{
                defaultNamingContext       = 'DC=contoso,DC=com'
                configurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
                schemaNamingContext        = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
                dnsHostName                = 'dc01.contoso.com'
            }
        }

        Mock Get-ADRootDSE -ModuleName Maester -ParameterFilter { $Server -eq 'dc01.fabrikam.net' } {
            [PSCustomObject]@{
                defaultNamingContext       = 'DC=fabrikam,DC=net'
                configurationNamingContext = 'CN=Configuration,DC=fabrikam,DC=net'
                schemaNamingContext        = 'CN=Schema,CN=Configuration,DC=fabrikam,DC=net'
                dnsHostName                = 'dc01.fabrikam.net'
            }
        }

        Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer 'dc01.contoso.com', 'dc01.fabrikam.net'

        Should -Invoke Get-ADRootDSE -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Server -eq 'dc01.contoso.com' }
        Should -Invoke Get-ADRootDSE -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Server -eq 'dc01.fabrikam.net' }
        InModuleScope Maester {
            $__MtSession.ADConnection.TargetServer | Should -Be 'dc01.contoso.com'
            $__MtSession.ADConnection.TargetServers | Should -Be @('dc01.contoso.com', 'dc01.fabrikam.net')
        }
    }

    It 'Does not call opt-in services when -Service All is specified' {
        Mock Get-AzContext -ModuleName Maester { [PSCustomObject]@{ Account = 'test@contoso.com' } }
        Mock Get-MtDataverseEnvironmentUrl -ModuleName Maester { $null }
        Mock Connect-ExchangeOnline -ModuleName Maester {}
        Mock Connect-IPPSSession -ModuleName Maester {}
        Mock Get-ConnectionInformation -ModuleName Maester { @() }
        Mock Connect-MgGraph -ModuleName Maester {}
        Mock Connect-MicrosoftTeams -ModuleName Maester {}
        Mock Connect-MtGitHub -ModuleName Maester { throw 'Connect-MtGitHub should not be called for -Service All.' }
        Mock Get-ADRootDSE -ModuleName Maester { throw 'Get-ADRootDSE should not be called for -Service All.' }

        Connect-Maester -Service All 3>$null 6>$null

        Should -Invoke Connect-MtGitHub -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Get-ADRootDSE -ModuleName Maester -Times 0 -Exactly
    }
}
