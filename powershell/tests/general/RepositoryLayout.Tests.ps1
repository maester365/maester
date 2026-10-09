# Guards the repository layout described in website/docs/contributing.md#repository-layout and AGENTS.md.
# When a rule here fails, move or rename the file to fit the layout. Change a rule only together with the guide.
BeforeDiscovery {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:HasGit = [bool](Get-Command git -ErrorAction SilentlyContinue) -and
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot '.git'))
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    # Tracked files only, so build output, clones and other ignored folders never trip the rules.
    $script:TrackedFiles = @(git -C $script:RepoRoot ls-files 2>$null)

    # The shared service names. A service folder has the same name wherever it appears:
    # tests/maester/<service>, tests/cisa/<service>, powershell/{public,internal}/services/<service> and
    # powershell/internal/checks/<suite>/<service>. Add a new service here and in the contributing guide.
    $script:ServiceNames = @(
        'ad', 'ai-agent', 'azure', 'azure-devops', 'defender', 'entra', 'exchange', 'github', 'global-secure-access',
        'graph', 'intune', 'purview', 'sharepoint', 'teams', 'xspm'
    )
    # Areas of the maester suite that are not a service.
    $script:MaesterAreas = @('drift')
    $script:Suites = @('ad', 'cis', 'cisa', 'custom', 'eidsca', 'maester', 'orca')
    $script:PublicGroups = @('app', 'connect', 'report', 'run', 'services')
    $script:InternalGroups = @('app', 'checks', 'connect', 'engine', 'generated', 'report', 'services', 'session', 'utility')
    $script:KebabCase = '^[a-z0-9]+(-[a-z0-9]+)*$'

    function Get-TrackedFolder {
        param([string[]] $Root)
        $folders = foreach ($file in $script:TrackedFiles) {
            if ($Root | Where-Object { $file.StartsWith("$_/", [System.StringComparison]::Ordinal) }) {
                $parts = $file.Split('/')
                for ($i = 1; $i -lt $parts.Count - 1; $i++) { $parts[0..$i] -join '/' }
            }
        }
        @($folders | Sort-Object -Unique)
    }

    function Get-ChildFolderName {
        param([string] $Parent)
        $prefix = "$Parent/"
        @($script:TrackedFiles | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::Ordinal) } |
                ForEach-Object { $_.Substring($prefix.Length) } | Where-Object { $_.Contains('/') } |
                ForEach-Object { $_.Split('/')[0] } | Sort-Object -Unique)
    }
}

Describe 'Repository layout' -Skip:(-not $script:HasGit) {
    Context 'Folder names' {
        It 'names every folder under tests/, powershell/ and build/ in lowercase kebab-case' {
            # Fixtures model users' own folders (for example a 2.x Custom folder), so they keep their names.
            $offenders = Get-TrackedFolder -Root 'tests', 'powershell', 'build' |
                Where-Object { $_ -notlike 'powershell/tests/fixtures/*' } |
                Where-Object { $_.Split('/')[-1] -cnotmatch $script:KebabCase }
            $offenders | Should -BeNullOrEmpty -Because 'folder names are lowercase kebab-case, for example tests/maester/global-secure-access'
        }

        It 'has no two tracked paths that differ only in case' {
            $collisions = $script:TrackedFiles | Group-Object { $_.ToLowerInvariant() } | Where-Object Count -GT 1 |
                ForEach-Object { $_.Group -join ' <-> ' }
            $collisions | Should -BeNullOrEmpty -Because 'they collide on case-insensitive file systems (Windows and macOS)'
        }
    }

    Context 'tests/ (the security checks)' {
        It 'holds only native tests, suite manifests and READMEs' {
            $offenders = $script:TrackedFiles | Where-Object { $_ -like 'tests/*' } |
                Where-Object { $_ -ne 'tests/maester-config.json' } |
                Where-Object { $_.Split('/')[-1] -cnotmatch '^(Test\.[A-Za-z0-9.-]+\.(ps1|md)|suite\.json|README\.md)$' }
            $offenders | Should -BeNullOrEmpty -Because 'a check is Test.<ID>.ps1 plus Test.<ID>.md; shared code belongs in powershell/internal'
        }

        It 'uses only the known suite folders at the top level' {
            $offenders = Get-ChildFolderName -Parent 'tests' | Where-Object { $_ -notin $script:Suites }
            $offenders | Should -BeNullOrEmpty -Because 'a new suite folder needs a suite.json and an entry in the contributing guide'
        }

        It 'gives every suite folder a suite.json' {
            $missing = Get-ChildFolderName -Parent 'tests' | Where-Object { $_ -ne 'custom' } |
                Where-Object { "tests/$_/suite.json" -notin $script:TrackedFiles }
            $missing | Should -BeNullOrEmpty
        }

        It 'names the service folders of the maester and cisa suites with the shared service names' {
            $offenders = @(
                Get-ChildFolderName -Parent 'tests/maester' | Where-Object { $_ -notin ($script:ServiceNames + $script:MaesterAreas) } |
                    ForEach-Object { "tests/maester/$_" }
                Get-ChildFolderName -Parent 'tests/cisa' | Where-Object { $_ -notin $script:ServiceNames } |
                    ForEach-Object { "tests/cisa/$_" }
            )
            $offenders | Should -BeNullOrEmpty -Because "service folders are named one of: $($script:ServiceNames -join ', ')"
        }
    }

    Context 'powershell/ (the module source)' {
        It 'keeps no function files directly in public/ or internal/' {
            $offenders = $script:TrackedFiles | Where-Object { $_ -match '^powershell/(public|internal)/[^/]+$' }
            $offenders | Should -BeNullOrEmpty -Because 'every function file belongs in a group folder such as public/run or internal/engine'
        }

        It 'groups public/ into run, connect, report, app and services' {
            $offenders = Get-ChildFolderName -Parent 'powershell/public' | Where-Object { $_ -notin $script:PublicGroups }
            $offenders | Should -BeNullOrEmpty
        }

        It 'groups internal/ into the documented folders' {
            $offenders = Get-ChildFolderName -Parent 'powershell/internal' | Where-Object { $_ -notin $script:InternalGroups }
            $offenders | Should -BeNullOrEmpty
        }

        It 'names service folders with the shared service names' {
            $offenders = foreach ($parent in 'powershell/public/services', 'powershell/internal/services') {
                Get-ChildFolderName -Parent $parent | Where-Object { $_ -notin $script:ServiceNames } | ForEach-Object { "$parent/$_" }
            }
            $offenders | Should -BeNullOrEmpty -Because "service folders are named one of: $($script:ServiceNames -join ', ')"
        }

        It 'mirrors the test suites in internal/checks' {
            $offenders = @(
                Get-ChildFolderName -Parent 'powershell/internal/checks' | Where-Object { $_ -notin $script:Suites } |
                    ForEach-Object { "powershell/internal/checks/$_" }
                foreach ($suite in 'maester', 'cisa') {
                    Get-ChildFolderName -Parent "powershell/internal/checks/$suite" |
                        Where-Object { $_ -notin ($script:ServiceNames + $script:MaesterAreas) } |
                        ForEach-Object { "powershell/internal/checks/$suite/$_" }
                }
            )
            $offenders | Should -BeNullOrEmpty -Because 'internal/checks/<suite>/<service> follows tests/<suite>/<service>'
        }

        It 'is referenced only by paths that exist' {
            # Docs, workflows, build scripts and unit tests that name a module source file must follow it when it moves.
            # History (blog posts, versioned docs, recorded results and fixtures) keeps the paths of its time.
            $historical = '^(website/(blog|versioned_docs|versioned_sidebars|docs/commands|docs/tests)/|docs/proposals/|build/(aitools|migration/reports)/|report/src/lib/|powershell/tests/fixtures/)'
            $offenders = foreach ($file in $script:TrackedFiles) {
                if ($file -match $historical -or $file -notmatch '\.(ps1|psm1|psd1|md|mdx|ya?ml|json|js|mjs)$') { continue }
                $path = Join-Path $script:RepoRoot $file
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
                $content = [System.IO.File]::ReadAllText($path)
                foreach ($match in [regex]::Matches($content, '(?<![\w/.-])powershell/(public|internal)/[\w./-]+?\.(ps1|psm1)\b')) {
                    if ($match.Value -notin $script:TrackedFiles) { "${file}: $($match.Value)" }
                }
                if ($file -like 'powershell/tests/*') {
                    foreach ($match in [regex]::Matches($content, '(?:\.\./)+(public|internal)/[\w./-]+?\.(ps1|psm1)\b')) {
                        $target = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $path -Parent) $match.Value))
                        if (-not (Test-Path -LiteralPath $target)) { "${file}: $($match.Value)" }
                    }
                }
            }
            $offenders | Should -BeNullOrEmpty -Because 'a moved file leaves these references dangling'
        }

        It 'names hand-written function files Verb-Noun.ps1' {
            $offenders = $script:TrackedFiles |
                Where-Object { $_ -match '^powershell/(public|internal)/.+\.ps1$' -and $_ -notlike 'powershell/internal/generated/*' } |
                Where-Object { $_.Split('/')[-1] -cnotmatch '^[A-Z][A-Za-z]+-[A-Z][A-Za-z0-9]+\.ps1$' }
            $offenders | Should -BeNullOrEmpty -Because 'one function per file, named after the function'
        }
    }
}
