BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Get-MtAzdoIdentityType' {
    BeforeAll {
        function New-TestJwt([hashtable] $Claims) {
            $json = $Claims | ConvertTo-Json -Compress
            $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            "eyJhbGciOiJub25lIn0.$payload.signature"
        }
        # Stands in for the ADOPS module so the helper can call NewAzToken in its scope
        $script:FakeAdops = New-Module -Name ADOPS -ScriptBlock {
            $script:Token = $null
            $script:Identity = $null
            function NewAzToken { @{ Token = $script:Token } }
            function Set-FakeToken($Value) { $script:Token = $Value }
            function Set-FakeIdentity($Value) { $script:Identity = $Value }
            function Get-ADOPSConnection { @{ Identity = $script:Identity } }
            Export-ModuleMember -Function Set-FakeToken, Set-FakeIdentity, Get-ADOPSConnection
        } | Import-Module -PassThru -Force
    }

    AfterAll {
        Remove-Module ADOPS -Force -ErrorAction SilentlyContinue
    }

    It 'Returns <Expected> for token claims <Name>' -ForEach @(
        @{ Name = 'idtyp user'; Claims = @{ idtyp = 'user'; scp = 'user_impersonation' }; Expected = 'User' }
        @{ Name = 'idtyp app'; Claims = @{ idtyp = 'app'; roles = @('Read') }; Expected = 'ServicePrincipal' }
        @{ Name = 'scp without idtyp'; Claims = @{ scp = 'user_impersonation' }; Expected = 'User' }
        @{ Name = 'neither idtyp nor scp'; Claims = @{ oid = '00000000-0000-0000-0000-000000000000' }; Expected = 'ServicePrincipal' }
    ) {
        Set-FakeToken (New-TestJwt $Claims)
        InModuleScope Maester { Get-MtAzdoIdentityType } | Should -Be $Expected
    }

    It 'Falls back to the ADOPS connection identity when the token cannot be decoded' -ForEach @(
        @{ Identity = 'admin@contoso.com'; Expected = 'User' }
        @{ Identity = '00000000-0000-0000-0000-000000000000'; Expected = 'ServicePrincipal' }
        @{ Identity = $null; Expected = 'Unknown' }
    ) {
        Set-FakeToken 'not-a-jwt'
        Set-FakeIdentity $Identity
        InModuleScope Maester { Get-MtAzdoIdentityType } | Should -Be $Expected
    }
}
