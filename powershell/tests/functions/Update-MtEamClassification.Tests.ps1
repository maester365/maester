BeforeAll {
    . "$PSScriptRoot/../../internal/Get-MtEamClassification.ps1"

    $buildScriptPath = Resolve-Path "$PSScriptRoot/../../../build/Update-MtEamClassification.ps1"
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($buildScriptPath, [ref]$null, [ref]$null)
    foreach ($function in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        . ([scriptblock]::Create($function.Extent.Text))
    }
}

Describe 'Get-EamClassificationData' {
    It 'projects role IDs and EAM tiers from valid source data' {
        $json = @(
            [pscustomobject]@{
                RoleId         = '{62E90394-69F5-4237-9190-012177145E10}'
                Classification = [pscustomobject]@{ EAMTierLevelName = 'ControlPlane' }
            }
            [pscustomobject]@{
                RoleId         = '4a5d8f65-41da-4de4-8968-e035b65339cf'
                Classification = [pscustomobject]@{ EAMTierLevelName = 'ManagementPlane' }
            }
        ) | ConvertTo-Json -Depth 5

        $result = @(Get-EamClassificationData -Json $json -MinimumRoleCount 2)

        $result.Count | Should -Be 2
        $result[0].RoleId | Should -Be '62e90394-69f5-4237-9190-012177145e10'
        $result[0].Tier | Should -Be 'ControlPlane'
    }

    It 'rejects duplicate role IDs' {
        $json = @(
            [pscustomobject]@{
                RoleId         = '62e9039469f542379190012177145e10'
                Classification = [pscustomobject]@{ EAMTierLevelName = 'ControlPlane' }
            }
            [pscustomobject]@{
                RoleId         = '62e90394-69f5-4237-9190-012177145e10'
                Classification = [pscustomobject]@{ EAMTierLevelName = 'ManagementPlane' }
            }
        ) | ConvertTo-Json -Depth 5

        { Get-EamClassificationData -Json $json -MinimumRoleCount 1 } | Should -Throw '*duplicate RoleId*'
    }

    It 'rejects unknown EAM tiers' {
        $json = @{
            RoleId         = '62e90394-69f5-4237-9190-012177145e10'
            Classification = @{ EAMTierLevelName = 'UnknownPlane' }
        } | ConvertTo-Json -Depth 5

        { Get-EamClassificationData -Json $json -MinimumRoleCount 1 } | Should -Throw '*unknown or empty EAM tier*'
    }
}

Describe 'Get-MtEamClassification' {
    It 'contains the generated classification for the current source snapshot' {
        $classification = Get-MtEamClassification

        $classification.Count | Should -Be 145
        $classification['62e90394-69f5-4237-9190-012177145e10'] | Should -Be 'ControlPlane'
        $classification['a0b1b346-4d3e-4e8b-98f8-753987be4970'] | Should -Be 'UserAccess'
        $classification.Values | Should -Contain 'Unclassified'
    }
}
