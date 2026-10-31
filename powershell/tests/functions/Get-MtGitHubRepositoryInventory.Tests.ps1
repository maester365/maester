BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MtGitHubRepositoryInventory
}

Describe 'Validated GitHub repository inventory identities' {
    BeforeEach {
        InModuleScope Maester { $__MtSession.GitHubConnection = [pscustomobject]@{ Organization = 'fixture-org' } }
        $script:inventoryRows = @()
        $script:integrity = $true
        $script:pagination = $true
        $script:kind = 'Array'
        Mock Invoke-MtGitHubRequest -ModuleName Maester {
            [pscustomobject]@{
                Data = $script:inventoryRows; ContentKind = $script:kind
                CollectionIntegrityValid = $script:integrity; PaginationComplete = $script:pagination
                Issues = @(); StartedUtc = [DateTimeOffset]::UtcNow; CompletedUtc = [DateTimeOffset]::UtcNow
            }
        }
    }
    AfterEach {
        InModuleScope Maester { $__MtSession.GitHubConnection = $null }
    }

    It 'Deduplicates matching identities while preserving the inventory gap (<Reverse>)' -ForEach @(@{ Reverse = $false }, @{ Reverse = $true }) {
        $script:inventoryRows = @(
            @{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = @{ login = 'fixture-org' } },
            @{ id = 200; name = 'FIXTURE-repo'; full_name = 'fixture-org/FIXTURE-repo'; owner = @{ login = 'fixture-org' } },
            @{ id = 202; name = 'unrelated'; full_name = 'fixture-org/unrelated'; owner = @{ login = 'fixture-org' } }
        ) | ConvertTo-Json -Depth 10 | ConvertFrom-Json -NoEnumerate
        if ($Reverse) { [array]::Reverse($script:inventoryRows) }
        $actual = Get-MtGitHubRepositoryInventory
        $actual.Repositories.Count | Should -Be 2
        @($actual.Repositories.id | Sort-Object) | Should -Be @(200, 202)
        $actual.Issues | Should -Contain 'Repository inventory contains a duplicate ID.'
    }

    It 'Excludes every identity involved in a <Conflict> association (<Reverse>)' -ForEach @(
        @{ Conflict = 'ID'; Reverse = $false }, @{ Conflict = 'ID'; Reverse = $true },
        @{ Conflict = 'path'; Reverse = $false }, @{ Conflict = 'path'; Reverse = $true },
        @{ Conflict = 'owner'; Reverse = $false }, @{ Conflict = 'owner'; Reverse = $true },
        @{ Conflict = 'malformed'; Reverse = $false }, @{ Conflict = 'malformed'; Reverse = $true },
        @{ Conflict = 'chained'; Reverse = $false }, @{ Conflict = 'chained'; Reverse = $true }
    ) {
        $rows = @(@{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = @{ login = 'fixture-org' } })
        switch ($Conflict) {
            'ID' { $rows += @{ id = 200; name = 'renamed'; full_name = 'fixture-org/renamed'; owner = @{ login = 'fixture-org' } } }
            'path' { $rows += @{ id = 201; name = 'FIXTURE-repo'; full_name = 'fixture-org/FIXTURE-repo'; owner = @{ login = 'fixture-org' } } }
            'owner' { $rows += @{ id = 200; name = 'fixture-repo'; full_name = 'foreign-org/fixture-repo'; owner = @{ login = 'foreign-org' } } }
            'malformed' { $rows += @{ id = 200; name = 'fixture-repo' } }
            'chained' {
                $rows += @{ id = 200; name = 'renamed'; full_name = 'fixture-org/renamed'; owner = @{ login = 'fixture-org' } }
                $rows += @{ id = 201; name = 'renamed'; full_name = 'fixture-org/renamed'; owner = @{ login = 'fixture-org' } }
            }
        }
        $rows += @{ id = 202; name = 'unrelated'; full_name = 'fixture-org/unrelated'; owner = @{ login = 'fixture-org' } }
        $script:inventoryRows = ConvertTo-Json -InputObject $rows -Depth 10 | ConvertFrom-Json -NoEnumerate
        if ($Reverse) { [array]::Reverse($script:inventoryRows) }
        $actual = Get-MtGitHubRepositoryInventory
        $actual.Repositories.Count | Should -Be 1
        $actual.Repositories[0].id | Should -Be 202
        $actual.Issues.Count | Should -BeGreaterThan 0
    }

    It 'Reports unusable or incomplete transport evidence (<Gap>)' -ForEach @(
        @{ Gap = 'integrity' }, @{ Gap = 'pagination' }, @{ Gap = 'shape' }, @{ Gap = 'object data' }
    ) {
        switch ($Gap) {
            'integrity' { $script:integrity = $false }
            'pagination' { $script:pagination = $false }
            'shape' { $script:kind = 'Object' }
            'object data' { $script:inventoryRows = [pscustomobject]@{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = [pscustomobject]@{ login = 'fixture-org' } } }
        }
        $actual = Get-MtGitHubRepositoryInventory
        $actual.Repositories.Count | Should -Be 0
        $actual.Issues.Count | Should -BeGreaterThan 0
    }

    It 'Retains a successful empty inventory without inventing identities or retrieval gaps' {
        $actual = Get-MtGitHubRepositoryInventory
        $actual.Repositories.Count | Should -Be 0
        $actual.Issues.Count | Should -Be 0
    }
}
