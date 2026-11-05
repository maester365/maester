# Unit tests for the tooling in build/steps that keeps the defender's path catalogue current: Update-MtLearnMirror.ps1,
# Find-MtStepCandidate.ps1 and Test-MtStepSource.ps1, and their helpers.
# No test makes a network call: the mirror is a git repository built in TestDrive, -NoFetch keeps git local, and
# the requests to Learn and to the Claude API are mocked.

Describe 'Step catalogue tooling' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:stepsFolder = Join-Path $script:repoRoot 'build/steps'
        $script:updateScript = Join-Path $script:stepsFolder 'Update-MtLearnMirror.ps1'
        $script:findScript = Join-Path $script:stepsFolder 'Find-MtStepCandidate.ps1'
        $script:testScript = Join-Path $script:stepsFolder 'Test-MtStepSource.ps1'
        . $script:updateScript
        . $script:findScript
        . $script:testScript

        # Split so that no line holds a localized Learn URL (LanguageNeutralMicrosoftUrls.Tests.ps1).
        $script:learn = 'https://learn.microsoft.com'
        $script:localized = 'https://learn.microsoft.com/' + 'en-us'

        function Invoke-FixtureGit {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Path, [string[]] $Arguments, [string] $Date = '2026-10-01T10:00:00Z')
            $env:GIT_AUTHOR_DATE = $Date
            $env:GIT_COMMITTER_DATE = $Date
            try {
                $output = & git -C $Path -c user.name=Maester -c user.email=tests@maester.dev -c commit.gpgsign=false -c core.hooksPath=/dev/null @Arguments 2>&1
                if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
            } finally {
                Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
            }
        }

        function New-FixturePage {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Path, [string] $Key, [string] $Body, [string] $Topic = 'how-to')
            $null = New-Item -ItemType Directory -Path (Split-Path $Path) -Force
            $text = @(
                '---'
                "title: Fixture $Key | Microsoft Learn"
                "canonicalUrl: $script:localized/$Key"
                "ms.topic: $Topic"
                "source_path: $Key.md"
                '---'
                ''
                $Body
            ) -join "`n"
            Set-Content -LiteralPath $Path -Value $text -Encoding utf8NoBOM -NoNewline
        }

        function New-FixtureState {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Mirror, [hashtable] $Pages)
            $state = [ordered]@{ version = 1; cursor = $null; pages = [ordered]@{} }
            foreach ($key in $Pages.Keys | Sort-Object) { $state.pages["$script:localized/$key"] = $Pages[$key] }
            $null = New-Item -ItemType Directory -Path (Join-Path $Mirror '.learn-mirror') -Force
            $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Mirror '.learn-mirror/state.json') -Encoding utf8NoBOM
        }

        # A mirror with this history:
        #   2026-10-01  page-a and page-b published
        #   2026-10-10  page-a: front matter only
        #   2026-10-20  page-b: its text changes
        #   2026-10-25  page-c published
        $script:cache = Join-Path $TestDrive 'cache'
        $script:fixtureMirror = Join-Path $script:cache 'mirrors/entra-docs-mirror'
        $null = New-Item -ItemType Directory -Path $script:fixtureMirror -Force
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'init', '-q', '-b', 'main'
        @{
            include = '^https://learn\.microsoft\.com/' + 'en-us/fixture/'
            exclude = @('^https://learn\.microsoft\.com/' + 'en-us/fixture/skip/')
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:fixtureMirror 'learn-mirror.config.json') -Encoding utf8NoBOM
        $bodyA = "# Page A`n`n## Prerequisites`n`n- A licence.`n`n## Steps`n`nCreate the policy first."
        $bodyB = "# Page B`n`nYou must turn it on."
        New-FixturePage -Path (Join-Path $script:fixtureMirror 'docs/page-a.md') -Key 'fixture/page-a' -Body $bodyA
        New-FixturePage -Path (Join-Path $script:fixtureMirror 'docs/page-b.md') -Key 'fixture/page-b' -Body $bodyB
        $statePages = @{
            'fixture/page-a'  = @{ path = 'docs/page-a.md'; sourcePath = 'page-a.md' }
            'fixture/page-b'  = @{ path = 'docs/page-b.md'; sourcePath = 'page-b.md' }
            # An old URL that Learn redirects, and an alias that shares its original's file.
            'fixture/old-b'   = @{ path = 'docs/page-b.md'; redirectedTo = "$script:localized/fixture/page-b" }
            'fixture/alias-a' = @{ aliasOf = "$script:localized/fixture/page-a" }
            # The state names a file that is not in the mirror.
            'fixture/gone'    = @{ path = 'docs/gone.md' }
        }
        New-FixtureState -Mirror $script:fixtureMirror -Pages $statePages
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'add', '-A'
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'commit', '-q', '-m', 'Mirror Learn: 2 added' -Date '2026-10-01T10:00:00Z'

        New-FixturePage -Path (Join-Path $script:fixtureMirror 'docs/page-a.md') -Key 'fixture/page-a' -Body $bodyA -Topic 'concept-article'
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'commit', '-q', '-am', 'Mirror Learn: 1 changed' -Date '2026-10-10T10:00:00Z'

        New-FixturePage -Path (Join-Path $script:fixtureMirror 'docs/page-b.md') -Key 'fixture/page-b' -Body "# Page B`n`nYou must turn it on, and then wait a day."
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'commit', '-q', '-am', 'Mirror Learn: 1 changed' -Date '2026-10-20T10:00:00Z'
        $script:changeSha = (& git -C $script:fixtureMirror rev-parse HEAD)

        New-FixturePage -Path (Join-Path $script:fixtureMirror 'docs/page-c.md') -Key 'fixture/page-c' -Body "# Page C`n`nNew."
        $statePages['fixture/page-c'] = @{ path = 'docs/page-c.md' }
        New-FixtureState -Mirror $script:fixtureMirror -Pages $statePages
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'add', '-A'
        Invoke-FixtureGit -Path $script:fixtureMirror -Arguments 'commit', '-q', '-m', 'Mirror Learn: 1 added' -Date '2026-10-25T10:00:00Z'

        # Answers from Learn for linked URLs that the mirror doesn't have under that key.
        $null = New-Item -ItemType Directory -Path $script:cache -Force
        @{
            Version   = 1
            Redirects = [ordered]@{
                'fixture/moved'   = [ordered]@{ Status = 'Redirect'; To = 'fixture/page-a'; Hops = 1; Checked = '2026-11-01T00:00:00Z' }
                'fixture/removed' = [ordered]@{ Status = 'Missing'; To = 'fixture/removed'; Hops = 0; Checked = '2026-11-01T00:00:00Z' }
                'fixture/unknown' = [ordered]@{ Status = 'Page'; To = 'fixture/unknown'; Hops = 0; Checked = '2026-11-01T00:00:00Z' }
                'graph/api/x'     = [ordered]@{ Status = 'Page'; To = 'graph/api/x'; Hops = 0; Checked = '2026-11-01T00:00:00Z' }
                'fixture/away'    = [ordered]@{ Status = 'External'; To = 'https://github.com/x'; Hops = 1; Checked = '2026-11-01T00:00:00Z' }
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:cache 'redirects.json') -Encoding utf8NoBOM

        # The index, written by the update script itself. -NoFetch and -Links None keep it off the network.
        $script:fixtureRoot = Join-Path $TestDrive 'repo'
        $null = New-Item -ItemType Directory -Path (Join-Path $script:fixtureRoot 'tests/maester/entra') -Force
        $guide = @(
            '# MT.9001'
            "See [the policy]($script:learn/Fixture/Page-A#create). Also $script:localized/fixture/page-b."
            "And ($script:learn/graph/api/x?view=graph-rest-1.0), <https://example.com/not-learn>."
            "The site itself: $script:learn/"
        ) -join "`n"
        Set-Content -LiteralPath (Join-Path $script:fixtureRoot 'tests/maester/entra/Test.MT.9001.md') -Value $guide -Encoding utf8NoBOM
        $script:updateResult = & $script:updateScript -Root $script:fixtureRoot -CachePath $script:cache -Mirror entra-docs-mirror -Links None -NoFetch 6>$null
        $script:index = Read-MtLearnIndex -CachePath $script:cache

        function New-FixtureCatalog {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Name, [object[]] $Steps)
            $folder = Join-Path $TestDrive $Name
            $null = New-Item -ItemType Directory -Path $folder -Force
            [ordered]@{ Product = 'entra'; Steps = $Steps } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $folder 'entra.json') -Encoding utf8NoBOM
            '{ "Goals": [] }' | Set-Content -LiteralPath (Join-Path $folder 'goals.json')
            $folder
        }
        function New-FixtureStep {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([string] $Id, [string] $Key, [string] $Reviewed, [string] $Mirror = 'entra-docs-mirror')
            [ordered]@{
                Id      = $Id
                Title   = "Title of $Id"
                Summary = 'Summary.'
                Sources = @([ordered]@{ Url = "$script:learn/$Key"; Mirror = $Mirror; Note = 'Note.'; Reviewed = $Reviewed })
            }
        }
    }

    Context 'Learn URLs' {
        It 'keys a URL by its path, without locale, anchor, query, trailing slash or case' {
            ConvertTo-MtLearnKey "$script:localized/Entra/Identity/Overview/?view=x#anchor" | Should -Be 'entra/identity/overview'
            ConvertTo-MtLearnKey "$script:learn/intune/" | Should -Be 'intune'
            ConvertTo-MtLearnKey 'https://docs.microsoft.com/' | Should -Be ''
            ConvertTo-MtLearnKey ('https://docs.microsoft.com/' + 'de-de/azure/active-directory/x') | Should -Be 'azure/active-directory/x'
        }

        It 'returns nothing for another site' {
            ConvertTo-MtLearnKey 'https://github.com/merill/entra-docs-mirror' | Should -BeNullOrEmpty
            ConvertTo-MtLearnKey 'https://learn.microsoft.com.example.com/x' | Should -BeNullOrEmpty
        }
    }

    Context 'Front matter' {
        It 'splits the front matter from the body and gives the body''s first line' {
            $split = Split-MtLearnFrontMatter -Text "---`r`ntitle: A page`r`nms.topic: how-to`r`nms.collection:`r`n- one`r`n---`r`n`r`n# A page`r`nText."
            $split.FrontMatter['title'] | Should -Be 'A page'
            $split.FrontMatter['ms.topic'] | Should -Be 'how-to'
            $split.FrontMatter.Contains('ms.collection') | Should -BeFalse
            $split.BodyLine | Should -Be 7
            $split.Body | Should -Be "`n# A page`nText."
        }

        It 'treats a page with no closing --- as all body' {
            $split = Split-MtLearnFrontMatter -Text "---`ntitle: x`nno end"
            $split.FrontMatter.Count | Should -Be 0
            $split.BodyLine | Should -Be 1
        }
    }

    Context 'Linked pages' {
        BeforeAll {
            $script:linkCatalog = New-FixtureCatalog -Name 'link-catalog' -Steps @(
                (New-FixtureStep -Id 'entra.a' -Key 'fixture/page-a' -Reviewed '2026-10-05'),
                [ordered]@{ Id = 'entra.m'; Title = 'M'; Summary = 'S.'; Sources = @(@{ Maintainer = 'merill'; Note = 'N.'; Reviewed = '2026-10-05' }) }
            )
        }

        It 'reads the Learn links of check guides and step sources, with where each comes from' {
            $links = @(Get-MtLearnLink -Root $script:fixtureRoot -CatalogPath $script:linkCatalog)
            $links.Key | Should -Be @('fixture/page-a', 'fixture/page-b', 'graph/api/x')
            $pageA = $links | Where-Object Key -EQ 'fixture/page-a'
            $pageA.From.Kind | Should -Be @('Source', 'Guide')
            ($pageA.From | Where-Object Kind -EQ 'Guide').Id | Should -Be 'MT.9001'
            ($pageA.From | Where-Object Kind -EQ 'Guide').Line | Should -Be 2
            ($links | Where-Object Key -EQ 'fixture/page-b').Url | Should -Be "$script:localized/fixture/page-b"
            ($links | Where-Object Key -EQ 'graph/api/x').Url | Should -Be "$script:learn/graph/api/x"
        }

        It 'reads only the step sources with -Links Catalog' {
            @(Get-MtLearnLink -Root $script:fixtureRoot -CatalogPath $script:linkCatalog -Links Catalog).Key | Should -Be @('fixture/page-a')
        }

        It 'lists the sources of each step, and maintainer sources without a Url' {
            $sources = @(Get-MtStepSource -Path $script:linkCatalog)
            $sources.Count | Should -Be 2
            $sources[0].Step | Should -Be 'entra.a'
            $sources[0].Reviewed | Should -Be '2026-10-05'
            $sources[1].Url | Should -BeNullOrEmpty
            $sources[1].Maintainer | Should -Be 'merill'
        }
    }

    Context 'Mirror index' {
        It 'indexes the pages the mirror state lists, with redirects and aliases' {
            $script:updateResult.Pages | Should -Be 5
            $script:index.Pages['fixture/page-a']['Path'] | Should -Be 'docs/page-a.md'
            $script:index.Pages['fixture/alias-a']['Path'] | Should -Be 'docs/page-a.md'
            $script:index.Pages['fixture/old-b']['Target'] | Should -Be 'fixture/page-b'
            $script:index.Pages['FIXTURE/PAGE-C']['Path'] | Should -Be 'docs/page-c.md'
        }

        It 'leaves out a page whose file is not in the mirror' {
            $script:index.Pages.ContainsKey('fixture/gone') | Should -BeFalse
        }

        It 'records the mirror''s commit and the URLs it covers' {
            $info = $script:index.Mirrors['entra-docs-mirror']
            $info['Commit'] | Should -Be (& git -C $script:fixtureMirror rev-parse HEAD)
            $info['Repository'] | Should -Be 'merill/entra-docs-mirror'
            $info['Include'] | Should -Match 'fixture'
        }

        It 'indexes a mirror with no state file from each page''s canonicalUrl' {
            $plain = Join-Path $TestDrive 'plain-mirror'
            $null = New-Item -ItemType Directory -Path $plain -Force
            Invoke-FixtureGit -Path $plain -Arguments 'init', '-q', '-b', 'main'
            New-FixturePage -Path (Join-Path $plain 'docs/one.md') -Key 'plain/one' -Body 'One.'
            Invoke-FixtureGit -Path $plain -Arguments 'add', '-A'
            Invoke-FixtureGit -Path $plain -Arguments 'commit', '-q', '-m', 'one'
            $content = Get-MtLearnMirrorPage -Path $plain 3>$null
            $content.Pages.Key | Should -Be 'plain/one'
            $content.Pages.Path | Should -Be 'docs/one.md'
        }

        It 'asks Learn only about linked pages with no mirror file and no fresh answer' {
            $links = @('fixture/page-a', 'fixture/new', 'fixture/fresh', 'fixture/stale', 'fixture/unreadable') | ForEach-Object { [pscustomobject]@{ Key = $_ } }
            $answers = [ordered]@{
                'fixture/fresh'      = @{ Checked = '2026-11-01T00:00:00Z' }
                'fixture/stale'      = @{ Checked = [datetime]::new(2026, 8, 1, 0, 0, 0, [System.DateTimeKind]::Utc) }
                'fixture/unreadable' = @{ Checked = 'not a date' }
            }
            $now = [datetime]::new(2026, 11, 5, 0, 0, 0, [System.DateTimeKind]::Utc)
            (Select-MtLearnLookup -Link $links -Pages $script:index.Pages -Redirects $answers -MaxAge 30 -Now $now).Key |
                Should -Be @('fixture/new', 'fixture/stale', 'fixture/unreadable')
            (Select-MtLearnLookup -Link $links -Pages $script:index.Pages -Redirects $answers -MaxAge 0 -Now $now).Key |
                Should -Be @('fixture/new', 'fixture/fresh', 'fixture/stale', 'fixture/unreadable')
        }
    }

    Context 'Asking Learn where a URL goes' {
        BeforeAll {
            Mock Start-Sleep { }
        }

        It 'follows redirects one hop at a time and records where they end' {
            Mock Send-MtLearnRequest {
                switch -Wildcard ($Uri) {
                    '*/mem/intune/old' { [pscustomobject]@{ Status = 301; Location = '/en-us/intune/intune/old'; RetryAfter = $null } }
                    '*/intune/intune/old' { [pscustomobject]@{ Status = 301; Location = '/en-us/intune/new'; RetryAfter = $null } }
                    '*/intune/new' { [pscustomobject]@{ Status = 200; Location = $null; RetryAfter = $null } }
                }
            }
            $answer = Resolve-MtLearnRedirect -Key 'mem/intune/old' -RequestsPerSecond 20
            $answer.Status | Should -Be 'Redirect'
            $answer.To | Should -Be 'intune/new'
            $answer.Hops | Should -Be 2
            $answer.Checked | Should -Match '^\d{4}-\d{2}-\d{2}T'
            Should -Invoke Send-MtLearnRequest -Times 3 -Exactly
        }

        It 'records a page that is served at its URL, even after a redirect that only adds a query' {
            Mock Send-MtLearnRequest {
                if ($Uri -like '*view=*') { [pscustomobject]@{ Status = 200; Location = $null; RetryAfter = $null } }
                else { [pscustomobject]@{ Status = 301; Location = '/en-us/graph/api/user-get?view=graph-rest-1.0'; RetryAfter = $null } }
            }
            $answer = Resolve-MtLearnRedirect -Key 'graph/api/user-get' -RequestsPerSecond 20
            $answer.Status | Should -Be 'Page'
            $answer.To | Should -Be 'graph/api/user-get'
        }

        It 'records a removed page and a redirect to another site' {
            Mock Send-MtLearnRequest { [pscustomobject]@{ Status = 404; Location = $null; RetryAfter = $null } }
            (Resolve-MtLearnRedirect -Key 'fixture/removed' -RequestsPerSecond 20).Status | Should -Be 'Missing'
            Mock Send-MtLearnRequest { [pscustomobject]@{ Status = 302; Location = 'https://techcommunity.microsoft.com/x'; RetryAfter = $null } }
            $answer = Resolve-MtLearnRedirect -Key 'fixture/away' -RequestsPerSecond 20
            $answer.Status | Should -Be 'External'
            $answer.To | Should -Be 'https://techcommunity.microsoft.com/x'
        }

        It 'waits and retries when Learn throttles' {
            $script:calls = 0
            Mock Send-MtLearnRequest {
                $script:calls++
                if ($script:calls -eq 1) { [pscustomobject]@{ Status = 429; Location = $null; RetryAfter = 7 } }
                else { [pscustomobject]@{ Status = 200; Location = $null; RetryAfter = $null } }
            }
            (Resolve-MtLearnRedirect -Key 'fixture/page' -RequestsPerSecond 20).Status | Should -Be 'Page'
            Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 7 } -Times 1 -Exactly
        }

        It 'caches nothing when Learn fails' {
            Mock Send-MtLearnRequest { [pscustomobject]@{ Status = 500; Location = $null; RetryAfter = $null } }
            Resolve-MtLearnRedirect -Key 'fixture/page' -RequestsPerSecond 20 3>$null | Should -BeNullOrEmpty
            Mock Send-MtLearnRequest { throw 'No network' }
            Resolve-MtLearnRedirect -Key 'fixture/page' -RequestsPerSecond 20 3>$null | Should -BeNullOrEmpty
        }
    }

    Context 'Resolving a URL to its mirror file' {
        It 'resolves <Url> to <Status>' -ForEach @(
            @{ Url = 'https://learn.microsoft.com/fixture/page-a'; Status = 'Mirrored'; Path = 'docs/page-a.md'; Resolved = 'fixture/page-a' }
            @{ Url = 'https://learn.microsoft.com/fixture/old-b'; Status = 'Redirected'; Path = 'docs/page-b.md'; Resolved = 'fixture/page-b' }
            @{ Url = 'https://learn.microsoft.com/fixture/moved'; Status = 'Redirected'; Path = 'docs/page-a.md'; Resolved = 'fixture/page-a' }
            @{ Url = 'https://learn.microsoft.com/fixture/unknown'; Status = 'NotInMirror'; Path = $null; Resolved = 'fixture/unknown' }
            @{ Url = 'https://learn.microsoft.com/graph/api/x'; Status = 'NotMirrored'; Path = $null; Resolved = 'graph/api/x' }
            @{ Url = 'https://learn.microsoft.com/fixture/removed'; Status = 'Missing'; Path = $null; Resolved = $null }
            @{ Url = 'https://learn.microsoft.com/fixture/away'; Status = 'External'; Path = $null; Resolved = $null }
            @{ Url = 'https://learn.microsoft.com/fixture/never-asked'; Status = 'Unresolved'; Path = $null; Resolved = $null }
        ) {
            $page = Resolve-MtLearnPage -Index $script:index -Url $Url
            $page.Status | Should -Be $Status
            $page.Path | Should -Be $Path
            $page.ResolvedKey | Should -Be $Resolved
            if ($Path) { $page.Mirror | Should -Be 'entra-docs-mirror' }
        }
    }

    Context 'Changed sources' {
        BeforeAll {
            $script:sourceCatalog = New-FixtureCatalog -Name 'source-catalog' -Steps @(
                (New-FixtureStep -Id 'entra.front-matter-only' -Key 'fixture/page-a' -Reviewed '2026-10-05'),
                (New-FixtureStep -Id 'entra.text-changed' -Key 'fixture/page-b' -Reviewed '2026-10-05'),
                (New-FixtureStep -Id 'entra.reviewed-on-change-day' -Key 'fixture/page-b' -Reviewed '2026-10-20'),
                (New-FixtureStep -Id 'entra.page-published-later' -Key 'fixture/page-c' -Reviewed '2026-10-05'),
                (New-FixtureStep -Id 'entra.reviewed-before-mirror' -Key 'fixture/page-a' -Reviewed '2026-09-01'),
                (New-FixtureStep -Id 'entra.old-url-other-mirror' -Key 'fixture/moved' -Reviewed '2026-10-05' -Mirror 'intune-docs-mirror'),
                (New-FixtureStep -Id 'entra.page-removed' -Key 'fixture/removed' -Reviewed '2026-10-05'),
                [ordered]@{ Id = 'entra.maintainer'; Title = 'M'; Summary = 'S.'; Sources = @(@{ Maintainer = 'merill'; Note = 'N.'; Reviewed = '2026-10-05' }) }
            )
            $script:sourceOut = Join-Path $TestDrive 'source-out'
            $script:sourceResults = @(& $script:testScript -Root $script:fixtureRoot -CachePath $script:cache -CatalogPath $script:sourceCatalog -OutputPath $script:sourceOut 6>$null)
            $script:sourceExit = $LASTEXITCODE
            $script:byStep = @{}
            foreach ($row in $script:sourceResults) { $script:byStep[$row.Step] = $row }
        }

        It 'checks every source with a Url and exits 1 when one needs review' {
            $script:sourceResults.Count | Should -Be 7
            $script:byStep.ContainsKey('entra.maintainer') | Should -BeFalse
            $script:sourceExit | Should -Be 1
        }

        It 'ignores commits that change only the front matter' {
            $row = $script:byStep['entra.front-matter-only']
            $row.Status | Should -Be 'Unchanged'
            $row.NeedsReview | Should -BeFalse
            $row.Detail | Should -Match '1 commit since the baseline changed only the front matter'
        }

        It 'lists the commit that changed the text, with a link to the file''s diff' {
            $row = $script:byStep['entra.text-changed']
            $row.Status | Should -Be 'Changed'
            $row.NeedsReview | Should -BeTrue
            @($row.Commits).Count | Should -Be 1
            $row.Commits[0].Sha | Should -Be $script:changeSha
            $hash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes('docs/page-b.md'))).ToLowerInvariant()
            $row.DiffLink | Should -Be "https://github.com/merill/entra-docs-mirror/commit/$($script:changeSha)#diff-$hash"
            $row.HistoryLink | Should -BeLike 'https://github.com/merill/entra-docs-mirror/commits/*/docs/page-b.md'
        }

        It 'counts a change on the Reviewed day as read' {
            $script:byStep['entra.reviewed-on-change-day'].Status | Should -Be 'Unchanged'
        }

        It 'reports a page that was published after Reviewed, and a mirror that starts after it' {
            $script:byStep['entra.page-published-later'].Status | Should -Be 'New'
            $script:byStep['entra.reviewed-before-mirror'].Status | Should -Be 'NoBaseline'
            $script:byStep['entra.page-removed'].Status | Should -Be 'NotFound'
            $script:byStep['entra.page-removed'].Detail | Should -Match '404'
        }

        It 'flags a URL that Learn redirects and a Mirror that names the wrong mirror' {
            $row = $script:byStep['entra.old-url-other-mirror']
            $row.Status | Should -Be 'Unchanged'
            $row.NeedsReview | Should -BeTrue
            $row.Problems | Should -HaveCount 2
            $row.Problems[0] | Should -Match 'redirects this URL to https://learn.microsoft.com/fixture/page-a'
            $row.Problems[1] | Should -Match 'Mirror is intune-docs-mirror, but the page is in entra-docs-mirror'
        }

        It 'writes the issue body with only the steps that need review' {
            $markdown = Get-Content -LiteralPath (Join-Path $script:sourceOut 'step-sources.md') -Raw
            $markdown | Should -Match '^<!-- maester-step-sources -->'
            $markdown | Should -Match '5 of 7 Learn sources need a maintainer to re-read the page, in 5 steps'
            $markdown | Should -Match '### `entra.text-changed` Title of entra.text-changed'
            $markdown | Should -Match ([regex]::Escape("[diff](https://github.com/merill/entra-docs-mirror/commit/$($script:changeSha)#diff-"))
            $markdown | Should -Not -Match 'entra.front-matter-only'
            $json = Get-Content -LiteralPath (Join-Path $script:sourceOut 'step-sources.json') -Raw | ConvertFrom-Json
            $json.Count | Should -Be 7
        }

        It 'exits 0 when no source needs review' {
            $null = & $script:testScript -Root $script:fixtureRoot -CachePath $script:cache -CatalogPath $script:sourceCatalog -Step 'entra.front-matter-only', 'entra.reviewed-on-change-*' 6>$null
            $LASTEXITCODE | Should -Be 0
        }

        It 'exits 2 when there is no index' {
            $null = & $script:testScript -Root $script:fixtureRoot -CachePath (Join-Path $TestDrive 'no-cache') -CatalogPath $script:sourceCatalog 6>$null 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It 'says so when every source is current' {
            $markdown = ConvertTo-MtStepSourceMarkdown -Result @($script:byStep['entra.front-matter-only']) -Checked '2026-11-05'
            $markdown | Should -Match 'All 1 Learn sources of the step catalogue match'
        }
    }

    Context 'Prerequisite text' {
        BeforeAll {
            $page = @(
                '# Require compliant devices - Microsoft Entra ID | Microsoft Learn'
                ''
                'Microsoft Entra ID works with first-party apps.'
                ''
                '## Prerequisites'
                ''
                '- A [Microsoft Entra ID P1](https://example.com/p1) licence.'
                '- Devices enrolled in **Intune**.'
                ''
                '### Licences'
                ''
                '| Feature | Licence |'
                '| --- | --- |'
                '| Policy | P1 |'
                ''
                '## Create a policy'
                ''
                'Create a compliance policy first. Then sign in. You must exclude your emergency access accounts.'
                ''
                '```powershell'
                '# You must not see this.'
                '```'
                ''
                '> [!WARNING]'
                "> The policy won't work as intended without a compliant device."
                ''
                'Select **Require multifactor authentication**, which requires Microsoft Entra ID P1.'
                'When a user first signs in, they pick a certificate.'
                ''
                '## Before you begin'
                ''
                'Read the overview.'
            )
            $script:found = @(Find-MtPrerequisiteText -Line $page -FirstLine 41)
        }

        It 'keeps a prerequisite section whole, with its subsections, up to the next heading of its level' {
            $sections = @($script:found | Where-Object Kind -EQ 'Section')
            $sections.Heading | Should -Be @('Prerequisites', 'Before you begin')
            $sections[0].Line | Should -Be 45
            $sections[0].EndLine | Should -Be 54
            $sections[0].Text | Should -Be "A Microsoft Entra ID P1 licence.`nDevices enrolled in Intune.`nFeature | Licence`nPolicy | P1"
            $sections[1].Text | Should -Be 'Read the overview.'
        }

        It 'keeps the sentences with ordering cues, with their line, heading and cues' {
            $sentences = @($script:found | Where-Object Kind -EQ 'Sentence')
            $sentences.Text | Should -Be @(
                'Create a compliance policy first.'
                'You must exclude your emergency access accounts.'
                "The policy won't work as intended without a compliant device."
                'Select Require multifactor authentication, which requires Microsoft Entra ID P1.'
            )
            $sentences[0].Line | Should -Be 58
            $sentences[0].Heading | Should -Be 'Create a policy'
            $sentences[0].Cues | Should -Be @('first')
            $sentences[2].Cues | Should -Be @('without')
            $sentences[3].Cues | Should -Be @('requires')
        }

        It 'leaves out code, first-party and first sign-in, and the bare verb require' {
            ($script:found.Text -join ' ') | Should -Not -Match 'not see this|first-party|first signs'
        }

        It 'looks only for the cues it is given' {
            $only = @(Find-MtPrerequisiteText -Line @('You must do it first.', 'You must not.') -Cue 'first')
            $only.Text | Should -Be 'You must do it first.'
        }
    }

    Context 'Note suggestions' {
        It 'measures the longest run of words shared with the page' {
            Measure-MtSharedWordRun -Text 'Create the compliance policy before the device' -Source 'You should create the compliance policy first.' | Should -Be 4
            Measure-MtSharedWordRun -Text '' -Source 'x' | Should -Be 0
        }

        It 'keeps a suggestion in its own words and rejects one that is copied, too long or not one line' {
            $page = [pscustomobject]@{ Url = 'u'; Candidates = @([pscustomobject]@{ Text = 'Create a compliance policy first and ensure you have at least one compliant device before proceeding.' }) }
            $notes = @(
                @{ note = 'Have Intune mark at least one device compliant before the policy is on.'; lines = @(74) }
                @{ note = 'Create a compliance policy first and ensure you have at least one compliant device.'; lines = @(74) }
                @{ note = ('x' * 201); lines = @() }
                @{ note = "Two`nlines."; lines = @() }
            )
            $response = [pscustomobject]@{ stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = (@{ notes = $notes; untrusted_instructions = $false } | ConvertTo-Json -Depth 5) }) }
            $suggestions = @(Get-MtStepNoteSuggestion -Page $page -Response $response)
            $suggestions.Accepted | Should -Be @($true, $false, $false, $false)
            $suggestions[1].Reason | Should -Match 'copies 14 words'
            $suggestions[2].Reason | Should -Match '201 characters'
            $suggestions[3].Reason | Should -Match 'more than one line'
        }

        It 'drops every suggestion when the model reports instructions in the page' {
            $page = [pscustomobject]@{ Url = 'u'; Candidates = @() }
            $response = [pscustomobject]@{ stop_reason = 'end_turn'; content = @([pscustomobject]@{ type = 'text'; text = '{"notes":[{"note":"x","lines":[]}],"untrusted_instructions":true}' }) }
            Get-MtStepNoteSuggestion -Page $page -Response $response 3>$null | Should -BeNullOrEmpty
        }

        It 'sends the page''s passages as data, inside tags the page cannot close' {
            $page = [pscustomobject]@{ Url = 'u'; Title = 'T'; LinkedFrom = [pscustomobject]@{ Steps = @('entra.a'); Tests = @('MT.1') }; Candidates = @([pscustomobject]@{ Line = 3; Heading = 'H'; Text = 'Do it first.' }) }
            $body = New-MtStepNoteRequest -Page $page -Model 'claude-sonnet-5-5'
            $body.model | Should -Be 'claude-sonnet-5-5'
            $body.messages[0].content | Should -Match '<learn_passages_(\d+)>\n\[line 3, under ''H''\] Do it first\.\n</learn_passages_\1>'
            $body.messages[0].content | Should -Match 'step entra.a, test MT.1'
            $body.output_config.format.type | Should -Be 'json_schema'
        }
    }

    Context 'Proposals file' {
        BeforeAll {
            $script:findCatalog = New-FixtureCatalog -Name 'find-catalog' -Steps @(New-FixtureStep -Id 'entra.a' -Key 'fixture/alias-a' -Reviewed '2026-10-05')
            $script:findOut = Join-Path $TestDrive 'find/step-candidates.json'
            Mock Invoke-WebRequest { throw 'No network calls in unit tests.' }
            $null = & $script:findScript -Root $script:fixtureRoot -CachePath $script:cache -CatalogPath $script:findCatalog -OutputPath $script:findOut 6>$null
            $script:proposals = Get-Content -LiteralPath $script:findOut -Raw | ConvertFrom-Json
        }

        It 'groups the URLs of one page and records who links it' {
            $pageA = $script:proposals.Pages | Where-Object Path -EQ 'docs/page-a.md'
            $pageA.Url | Should -Be 'https://learn.microsoft.com/fixture/page-a'
            $pageA.LinkedAs.Count | Should -Be 2
            $pageA.LinkedFrom.Steps | Should -Be 'entra.a'
            $pageA.LinkedFrom.Tests | Should -Be 'MT.9001'
            $pageA.Topic | Should -Be 'concept-article'
            $pageA.Title | Should -Be 'Fixture fixture/page-a'
            $script:proposals.Pages[0].Path | Should -Be 'docs/page-a.md'
        }

        It 'links each proposal to its line in the mirror' {
            $pageA = $script:proposals.Pages | Where-Object Path -EQ 'docs/page-a.md'
            $pageA.Candidates.Kind | Should -Be @('Section', 'Sentence')
            $pageA.Candidates[1].Text | Should -Be 'Create the policy first.'
            $pageA.Candidates[1].Line | Should -Be 16
            $pageA.Candidates[1].Link | Should -Be "https://github.com/merill/entra-docs-mirror/blob/$(& git -C $script:fixtureMirror rev-parse HEAD)/docs/page-a.md?plain=1#L16"
            $pageA.SuggestedNotes.Count | Should -Be 0
        }

        It 'lists the linked pages that no mirror has' {
            $script:proposals.NotFound.Url | Should -Be 'https://learn.microsoft.com/graph/api/x'
            $script:proposals.NotFound.Status | Should -Be 'NotMirrored'
        }

        It 'needs an API key for -SuggestNote' {
            $saved = $env:ANTHROPIC_API_KEY
            try {
                $env:ANTHROPIC_API_KEY = $null
                { & $script:findScript -Root $script:fixtureRoot -CachePath $script:cache -CatalogPath $script:findCatalog -OutputPath $script:findOut -SuggestNote 6>$null } |
                    Should -Throw '*ANTHROPIC_API_KEY*'
            } finally {
                $env:ANTHROPIC_API_KEY = $saved
            }
        }
    }

    Context 'Workflow' {
        BeforeAll {
            $script:workflow = Get-Content -LiteralPath (Join-Path $script:repoRoot '.github/workflows/step-sources.yaml') -Raw
        }

        It 'runs weekly and by hand, with only the permissions it needs' {
            $script:workflow | Should -Match '(?m)^  schedule:\s*\n\s*- cron: ''\d+ \d+ \* \* \d'''
            $script:workflow | Should -Match '(?m)^  workflow_dispatch:'
            $script:workflow | Should -Match '(?m)^permissions: \{\}'
            $script:workflow | Should -Match '(?m)^    permissions:\r?\n      contents: read\r?\n      issues: write\r?\n\r?\n    steps:'
            $script:workflow | Should -Match 'persist-credentials: false'
        }

        It 'keeps one issue and never opens a pull request' {
            $script:workflow | Should -Match 'gh issue edit'
            $script:workflow | Should -Not -Match 'pull-requests:|gh pr |create-pull-request'
        }
    }
}
