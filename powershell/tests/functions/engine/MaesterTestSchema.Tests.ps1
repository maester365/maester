BeforeAll {
    Import-Module "$PSScriptRoot/../../../lib/Maester.Engine.dll" -Force
    $script:schema = Import-PowerShellDataFile -Path "$PSScriptRoot/../../../assets/MaesterTestSchema.psd1"
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
}

Describe 'MaesterTest schema table' {
    It 'Lists exactly the properties of MaesterTestAttribute' {
        $classProperties = [MaesterTestAttribute].GetProperties() |
            Where-Object { $_.DeclaringType -eq [MaesterTestAttribute] } | ForEach-Object Name
        @($script:schema.Properties.Keys) | Sort-Object | Should -Be ($classProperties | Sort-Object)
    }

    It 'Declares the same type as the attribute for <_>' -ForEach @(
        'Id', 'Title', 'Severity', 'Category', 'Tag', 'Preview', 'LongRunning', 'Service', 'CompatibleLicense',
        'TenantType', 'Cloud', 'Platform', 'InstanceSource', 'Exclusive', 'Author', 'Contributor', 'HelpUrl'
    ) {
        $map = @{ 'System.String' = 'string'; 'System.String[]' = 'string[]'; 'System.Boolean' = 'bool' }
        $clrType = [MaesterTestAttribute].GetProperty($_).PropertyType.FullName
        $script:schema.Properties[$_].Type | Should -Be $map[$clrType]
    }

    It 'Gives every property a type, a required level and a description' {
        foreach ($name in $script:schema.Properties.Keys) {
            $p = $script:schema.Properties[$name]
            $p.Type | Should -BeIn @('string', 'string[]', 'bool') -Because $name
            $p.Required | Should -BeIn @('Always', 'BuiltIn', 'No') -Because $name
            $p.Description | Should -Not -BeNullOrEmpty -Because $name
        }
    }

    It 'Lists exactly the properties of MaesterParameterAttribute' {
        $classProperties = [MaesterParameterAttribute].GetProperties() |
            Where-Object { $_.DeclaringType -eq [MaesterParameterAttribute] } | ForEach-Object Name
        @($script:schema.ParameterAttribute.Keys) | Sort-Object | Should -Be ($classProperties | Sort-Object)
    }

    It 'Uses one ID grammar' {
        $script:schema.Properties.Id.Pattern | Should -Be $script:schema.IdPattern
        $script:schema.Properties.Id.MaxLength | Should -Be $script:schema.IdMaxLength
    }

    It 'Does not reuse a reserved name as a property' {
        foreach ($name in $script:schema.ReservedNames) {
            $script:schema.Properties.Contains($name) | Should -BeFalse -Because $name
        }
    }
}

Describe 'MaesterTest ID grammar' {
    It 'Accepts <_>' -ForEach @('MT.1198', 'CISA.MS.AAD.3.5', 'AD-USER-07', 'CT0001', 'CONTOSO.1001', 'EIDSCA.AF01', 'MT.1060.Drift_1', 'CIS.M365.1.1.3') {
        $_ | Should -Match $script:schema.IdPattern
    }

    It 'Rejects <_>' -ForEach @('1ABC', 'ABC', 'MT..1', 'MT.', '.MT1', 'MT 1001', 'MT.10/01', 'MT_1001') {
        $_ | Should -Not -Match $script:schema.IdPattern
    }

    It 'Accepts every static ID of the built-in tests' {
        $ids = foreach ($file in Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -Filter '*.Tests.ps1') {
            if ($file.FullName -match '[\\/]Custom[\\/]') { continue }
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $its = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'It'
                }, $true)
            foreach ($it in $its) {
                $name = $it.CommandElements | Select-Object -Skip 1 |
                    Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } |
                    Select-Object -First 1
                # Family wrappers build their IDs at run time ('MT1060.<_.Name>.1'); they become InstanceSource tests.
                if (-not $name -or $name.Value -notmatch ':' -or $name.Value -match '<') { continue }
                ($name.Value -split ':', 2)[0].Trim()
            }
        }
        # Checks migrated to the native format: their ID is in the file name and the attribute.
        $ids = @($ids) + @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -Filter 'Test.*.ps1' |
                Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' } |
                ForEach-Object { $_.Name -replace '^Test\.', '' -replace '\.ps1$', '' })
        $ids = $ids | Sort-Object -Unique
        $ids.Count | Should -BeGreaterThan 500
        $invalid = $ids | Where-Object { $_ -notmatch $script:schema.IdPattern -or $_.Length -gt $script:schema.IdMaxLength }
        $invalid | Should -BeNullOrEmpty
    }
}
