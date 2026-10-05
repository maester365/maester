BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:kdsBase = 'CN=Master Root Keys,CN=Group Key Distribution Service,CN=Services,' +
        'CN=Configuration,DC=contoso,DC=com'

    function Get-ConfigurationContainer {
        $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('localhost')
        try {
            InModuleScope Maester -Parameters @{ Connection = $connection } {
                param($Connection)
                Get-MtLdapConfigurationContainer -Connection $Connection `
                    -ConfigurationNamingContext 'CN=Configuration,DC=contoso,DC=com'
            }
        } finally {
            $connection.Dispose()
        }
    }
}

Describe 'Get-MtLdapConfigurationContainer' {
    It 'reads the KDS root keys from the Group Key Distribution Service container' {
        Mock Invoke-MtLdapSearch -ModuleName Maester -MockWith {
            if ($SearchBase -eq $script:kdsBase) {
                [PSCustomObject]@{ DistinguishedName = "CN=key1,$SearchBase"; name = 'key1' }
            }
        }

        $result = Get-ConfigurationContainer

        @($result.KdsRootKeys).Count | Should -Be 1
        Should -Invoke Invoke-MtLdapSearch -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $SearchBase -eq $script:kdsBase -and $Scope -eq 'OneLevel' -and
            $Filter -eq '(objectClass=msKds-ProvRootKey)'
        }
    }
}
