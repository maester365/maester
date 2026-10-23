BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:Check = Join-Path $script:RepoRoot 'build/packs/Test-MtPackRegistry.ps1'
    Import-Module (Join-Path $script:RepoRoot 'powershell/Maester.psd1') -Force

    # A registry of one or more publisher files under TestDrive, and the problems the check finds in it. -Root is
    # where packs/ is read; by default a folder without one, so the packs that ship with Maester don't count.
    $script:EmptyRoot = (New-Item -Path (Join-Path $TestDrive 'empty-root') -ItemType Directory -Force).FullName
    function script:Test-Registry {
        param([hashtable] $Publishers, [string] $Root = $script:EmptyRoot)
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        $null = New-Item -Path (Join-Path $path 'publishers') -ItemType Directory -Force
        foreach ($name in $Publishers.Keys) {
            $value = $Publishers[$name]
            $text = if ($value -is [string]) { $value } else { $value | ConvertTo-Json -Depth 5 }
            Set-Content -LiteralPath (Join-Path $path "publishers/$name") -Value $text
        }
        # Joined into one string, so Should -Match looks at every problem.
        (@(& $script:Check -Root $Root -Path $path) -join "`n")
    }

    function script:New-Publisher {
        param([string] $Publisher = 'contoso', [string] $Name = 'Contoso', [object[]] $Packs)
        if (-not $PSBoundParameters.ContainsKey('Packs')) { $Packs = @(New-RegisteredPack -Id "$Publisher.google-workspace" -Code 'CNT') }
        [ordered]@{
            Guid      = [guid]::NewGuid().ToString()
            Publisher = $Publisher
            Name      = $Name
            Owners    = @([ordered]@{ Login = 'contoso-admin'; Id = 1001 })
            Packs     = @($Packs)
        }
    }

    function script:New-RegisteredPack {
        param([string] $Id, [string] $Code, [string] $Guid = [guid]::NewGuid().ToString())
        [ordered]@{ Guid = $Guid; Id = $Id; Code = $Code; Repository = "https://github.com/$($Id.Split('.')[0])/pack" }
    }
}

Describe 'Maester Pack registry' {
    It 'is valid' {
        $problems = @(& $script:Check -Root $script:RepoRoot)
        $problems | Should -BeNullOrEmpty -Because ($problems -join "`n")
    }

    It 'accepts a valid publisher with a dotted code' {
        $publisher = New-Publisher -Packs @(New-RegisteredPack -Id 'contoso.google-workspace' -Code 'CNT.GWS')
        Test-Registry @{ 'contoso.json' = $publisher } | Should -BeNullOrEmpty
    }

    It 'refuses a GUID used twice, across publishers and packs' {
        $a = New-Publisher
        $b = New-Publisher -Publisher 'fabrikam' -Name 'Fabrikam' -Packs @(New-RegisteredPack -Id 'fabrikam.okta-checks' -Code 'FAB' -Guid $a.Guid)
        $problems = Test-Registry @{ 'contoso.json' = $a; 'fabrikam.json' = $b }
        $problems | Should -Match 'already used by The publisher in publishers/contoso.json'
        $problems.Split("`n") | Should -HaveCount 1
    }

    It 'refuses a GUID that is not a GUID' {
        $publisher = New-Publisher
        $publisher.Guid = 'not-a-guid'
        Test-Registry @{ 'contoso.json' = $publisher } | Should -Match 'is not a GUID'
    }

    It 'refuses two publishers with the same display name' {
        $problems = Test-Registry @{
            'contoso.json'  = New-Publisher
            'fabrikam.json' = New-Publisher -Publisher 'fabrikam' -Name 'contoso' -Packs @(New-RegisteredPack -Id 'fabrikam.okta-checks' -Code 'FAB')
        }
        $problems | Should -Match "the Name 'contoso' is already used"
    }

    It 'refuses a file not named after its publisher' {
        Test-Registry @{ 'other.json' = New-Publisher } | Should -Match 'must be named after its Publisher'
    }

    It 'refuses the same code twice and a code that overlaps another' {
        $a = New-Publisher -Packs @(New-RegisteredPack -Id 'contoso.google-workspace' -Code 'CNT')
        $b = New-Publisher -Publisher 'fabrikam' -Name 'Fabrikam' -Packs @(
            New-RegisteredPack -Id 'fabrikam.okta-checks' -Code 'CNT'
            New-RegisteredPack -Id 'fabrikam.slack-checks' -Code 'CNT.SLK'
        )
        $problems = Test-Registry @{ 'contoso.json' = $a; 'fabrikam.json' = $b }
        @($problems.Split("`n") | Where-Object { $_ -match "overlaps the code 'CNT' of contoso.google-workspace" }) | Should -HaveCount 2
    }

    It 'refuses a pack ID registered twice, and one that does not start with its publisher' {
        $publisher = New-Publisher -Packs @(
            New-RegisteredPack -Id 'contoso.google-workspace' -Code 'CNT'
            New-RegisteredPack -Id 'contoso.google-workspace' -Code 'CNX'
            New-RegisteredPack -Id 'fabrikam.okta-checks' -Code 'CNY'
        )
        $problems = Test-Registry @{ 'contoso.json' = $publisher }
        $problems | Should -Match "'contoso.google-workspace' is already registered"
        $problems | Should -Match "'fabrikam.okta-checks' must start with 'contoso.'"
    }

    It 'refuses a reserved code and a code in lower case' {
        $publisher = New-Publisher -Packs @(
            New-RegisteredPack -Id 'contoso.google-workspace' -Code 'GWS'
            New-RegisteredPack -Id 'contoso.okta-checks' -Code 'cnt'
        )
        $problems = Test-Registry @{ 'contoso.json' = $publisher }
        $problems | Should -Match "The code 'GWS' is reserved"
        $problems | Should -Match "has the Code 'cnt'"
    }

    It 'refuses an owner without a numeric GitHub ID, and an unknown key' {
        $publisher = New-Publisher
        $publisher.Owners = @([ordered]@{ Login = 'contoso-admin'; Id = 'contoso-admin' })
        $publisher.Website = 'https://contoso.com'
        $problems = Test-Registry @{ 'contoso.json' = $publisher }
        $problems | Should -Match 'needs its numeric GitHub Id'
        $problems | Should -Match "has the key 'Website'"
    }

    It 'refuses a file that is not JSON' {
        Test-Registry @{ 'contoso.json' = '{ "Guid": ' } | Should -Match 'is not valid JSON'
    }

    It 'refuses a built-in pack that is not registered, or whose code or GUID differs' {
        $root = Join-Path $TestDrive 'repo'
        $null = New-Item -Path (Join-Path $root 'packs/sample') -ItemType Directory -Force
        $guid = [guid]::NewGuid().ToString()
        Set-Content -LiteralPath (Join-Path $root 'packs/sample/maester-pack.json') -Value (@{ Id = 'maester.sample'; Code = 'SMP'; Guid = $guid } | ConvertTo-Json)

        Test-Registry -Root $root @{ 'contoso.json' = New-Publisher } | Should -Match 'must be registered in publishers/maester365.json'

        $maester = New-Publisher -Publisher 'maester365' -Name 'Maester' -Packs @(New-RegisteredPack -Id 'maester.sample' -Code 'SMQ')
        $problems = Test-Registry -Root $root @{ 'maester365.json' = $maester }
        $problems | Should -Match "the Code is 'SMP', but the registry has 'SMQ'"
        $problems | Should -Match "the Guid is '$guid'"

        $maester = New-Publisher -Publisher 'maester365' -Name 'Maester' -Packs @(New-RegisteredPack -Id 'maester.sample' -Code 'SMP' -Guid $guid)
        Test-Registry -Root $root @{ 'maester365.json' = $maester } | Should -BeNullOrEmpty
    }
}
