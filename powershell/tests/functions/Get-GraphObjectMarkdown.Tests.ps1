Describe 'Get-GraphObjectMarkdown' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Get-GraphObjectMarkdown
    }

    It 'escapes Markdown in a tenant display name so it cannot break the link or a table row' {
        $policy = [pscustomobject]@{
            id          = '00000000-0000-0000-0000-000000000001'
            displayName = 'Microsoft-managed: A [B] | C'
        }

        $link = Get-GraphObjectMarkdown -GraphObjects $policy -GraphObjectType ConditionalAccess -AsPlainTextLink

        $link | Should -BeLike '`[Microsoft-managed: A \`[B\`] \| C`](*PolicyBlade/policyId/00000000-0000-0000-0000-000000000001)'
    }

    It 'keeps a plain display name unchanged in the list form' {
        $policy = [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000002'; displayName = 'Require MFA' }

        Get-GraphObjectMarkdown -GraphObjects $policy -GraphObjectType ConditionalAccess |
            Should -BeLike '  - `[Require MFA`](*PolicyBlade/policyId/00000000-0000-0000-0000-000000000002)*'
    }
}
