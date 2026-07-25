Describe 'Test-MtHighPrivilegeServicePrincipalsForAllUsers' {
    BeforeAll {
        $script:monitoredAppIds = @(
            '1950a258-227b-4e31-a9cf-717495945fc2'
            '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
            '14d82eec-204b-4c2f-b7e8-296a70dab67e'
            'de8bc8b5-d9f9-48b1-a8ad-b748da725064'
            '1b730954-1685-4b74-9bfd-dac224a7b894'
            '12128f48-ec9e-42f0-b203-ea49fb6af367'
            'fb78d390-0c51-40cd-8e17-fdbfab77341b'
            '9bc3ab49-b65d-410a-85ad-de819febfddc'
            '9cee029c-6210-4654-90bb-17e6e9d36617'
        )

        function Get-TestServicePrincipal {
            param(
                [string] $AppId,
                [bool] $AssignmentRequired = $true,
                [bool] $AccountEnabled = $true
            )

            return [pscustomobject]@{
                id                        = "sp-$AppId"
                displayName               = "App $AppId"
                appId                     = $AppId
                appRoleAssignmentRequired = $AssignmentRequired
                accountEnabled            = $AccountEnabled
            }
        }
    }

    BeforeEach {
        $script:testResultMarkdown = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result)

            $script:testResultMarkdown = $Result
        }

        InModuleScope Maester {
            $__MtSession.AdminPortalUrl = @{
                Entra = 'https://entra.microsoft.us/'
            }
        }
    }

    It 'fails when a monitored first-party service principal is missing' {
        $servicePrincipals = $script:monitoredAppIds |
            Select-Object -Skip 1 |
            ForEach-Object { Get-TestServicePrincipal -AppId $_ }
        Mock -ModuleName Maester Invoke-MtGraphRequest { return $servicePrincipals }

        Test-MtHighPrivilegeServicePrincipalsForAllUsers | Should -BeFalse
        $script:testResultMarkdown | Should -Match 'Service principal missing \(assignment not enforced\)'
        $script:testResultMarkdown | Should -Match 'Microsoft Azure PowerShell'
    }

    It 'passes when every monitored service principal requires assignment' {
        $servicePrincipals = $script:monitoredAppIds |
            ForEach-Object { Get-TestServicePrincipal -AppId $_ }
        Mock -ModuleName Maester Invoke-MtGraphRequest { return $servicePrincipals }

        Test-MtHighPrivilegeServicePrincipalsForAllUsers | Should -BeTrue
        $script:testResultMarkdown | Should -Match 'Well done'
        $script:testResultMarkdown | Should -Match 'https://entra\.microsoft\.us/'
    }

    It 'fails when a disabled service principal does not require assignment' {
        $servicePrincipals = $script:monitoredAppIds |
            ForEach-Object { Get-TestServicePrincipal -AppId $_ }
        $servicePrincipals[0].appRoleAssignmentRequired = $false
        $servicePrincipals[0].accountEnabled = $false
        Mock -ModuleName Maester Invoke-MtGraphRequest { return $servicePrincipals }

        Test-MtHighPrivilegeServicePrincipalsForAllUsers | Should -BeFalse
        $script:testResultMarkdown | Should -Match 'Disabled \(assignment not required\)'
    }

    It 'documents that the Azure CLI app also covers Azure Developer CLI' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtHighPrivilegeServicePrincipalsForAllUsers | Should -BeFalse
        $script:testResultMarkdown | Should -Match 'Azure Developer CLI'
    }
}
