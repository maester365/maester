BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Get-MtXspmUnifiedIdentityInfo external data sources' {
    BeforeEach {
        $script:xspmQuery = $null

        Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting {
            return $null
        }
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery {
            param($Query)
            $script:xspmQuery = $Query
            return [PSCustomObject]@{ Result = @() }
        }
    }

    It 'uses the built-in HTTPS sources in the hunting query' {
        InModuleScope Maester {
            Get-MtXspmUnifiedIdentityInfo | Should -Not -BeNullOrEmpty
        }

        $script:xspmQuery | Should -Match 'https://raw\.githubusercontent\.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles\.json'
        $script:xspmQuery | Should -Match 'https://raw\.githubusercontent\.com/merill/microsoft-info/main/_info/MicrosoftApps\.json'
        $script:xspmQuery | Should -Match 'https://raw\.githubusercontent\.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_ApiPermissions\.json'
        $script:xspmQuery | Should -Match 'https://raw\.githubusercontent\.com/Cloud-Architekt/AzurePrivilegedIAM/refs/heads/main/PrivilegedOperations/ArmApiRequest\.csv'
        Should -Invoke Invoke-MtGraphSecurityQuery -ModuleName Maester -Exactly 1
    }

    It 'uses configured HTTPS mirrors for all four data sources' {
        $config = [PSCustomObject]@{
            EntraDirectoryRoles = 'https://mirror.contoso.com/roles.json'
            MicrosoftApps       = 'https://mirror.contoso.com/apps.json'
            ApiPermissions      = 'https://mirror.contoso.com/permissions.json'
            ArmApiRequests      = 'https://mirror.contoso.com/arm.csv'
        }
        Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting {
            return $config
        }

        InModuleScope Maester {
            Get-MtXspmUnifiedIdentityInfo | Should -Not -BeNullOrEmpty
        }

        $script:xspmQuery | Should -Match 'https://mirror\.contoso\.com/roles\.json'
        $script:xspmQuery | Should -Match 'https://mirror\.contoso\.com/apps\.json'
        $script:xspmQuery | Should -Match 'https://mirror\.contoso\.com/permissions\.json'
        $script:xspmQuery | Should -Match 'https://mirror\.contoso\.com/arm\.csv'
        $script:xspmQuery | Should -Not -Match 'raw\.githubusercontent\.com'
    }

    It 'rejects invalid source <Uri> before querying Graph' -ForEach @(
        @{ Uri = 'http://mirror.contoso.com/roles.json' }
        @{ Uri = "https://mirror.contoso.com/roles.json' ] | where true" }
        @{ Uri = 'https://user:secret@mirror.contoso.com/roles.json' }
        @{ Uri = 'https://mirror.contoso.com/roles.json#fragment' }
        @{ Uri = '' }
    ) {
        Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting {
            return [PSCustomObject]@{
                EntraDirectoryRoles = $Uri
            }
        }

        {
            InModuleScope Maester {
                Get-MtXspmUnifiedIdentityInfo
            }
        } | Should -Throw '*must be an absolute HTTPS URI*'

        Should -Invoke Invoke-MtGraphSecurityQuery -ModuleName Maester -Times 0 -Exactly
    }

    It 'identifies the external data sources when Advanced Hunting rejects the query' {
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery {
            throw 'externaldata failed'
        }

        {
            InModuleScope Maester {
                Get-MtXspmUnifiedIdentityInfo
            }
        } | Should -Throw '*externaldata failed*EntraDirectoryRoles=https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json*'
    }

    It 'preserves partial overrides and redacts a signed URI from <ErrorPrefix> errors' -ForEach @(
        @{ ErrorPrefix = 'externaldata: Cannot read' }
        @{ ErrorPrefix = 'Cannot read' }
    ) {
        Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting {
            @{ MicrosoftApps = 'https://mirror.contoso.com/apps.json?sig=secret' }
        }
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery {
            param($Query)
            $Query | Should -Match 'https://mirror.contoso.com/apps.json\?sig=secret'
            $Query | Should -Match 'raw.githubusercontent.com/Cloud-Architekt'
            throw "$ErrorPrefix https://mirror.contoso.com/apps.json?sig=secret"
        }
        $message = try { InModuleScope Maester { Get-MtXspmUnifiedIdentityInfo }; '' } catch { $_.Exception.Message }
        $message | Should -Match 'Cannot read https://mirror.contoso.com/apps.json'
        $message | Should -Not -Match 'secret'
        Should -Invoke Get-MtMaesterConfigGlobalSetting -ModuleName Maester -Exactly 1 -ParameterFilter { $Verbose -eq $false }
        Should -Invoke Invoke-MtGraphSecurityQuery -ModuleName Maester -Exactly 1 -ParameterFilter { $Verbose -eq $false }
    }

    It 'does not diagnose a licensing failure as an externaldata failure' {
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { throw 'License required' }
        $message = try { InModuleScope Maester { Get-MtXspmUnifiedIdentityInfo }; '' } catch { $_.Exception.Message }
        $message | Should -Match 'Original error: License required'
        $message | Should -Not -Match 'externaldata|EntraDirectoryRoles=|MicrosoftApps=|ApiPermissions=|ArmApiRequests='
    }
}
