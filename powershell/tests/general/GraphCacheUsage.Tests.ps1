BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    # Files that may declare or forward a DisableCache switch. They offer it to callers; nothing in a Maester run
    # passes it. Checks report on one snapshot of the tenant, so every check and helper reads through the session cache.
    $script:AllowedFiles = @(
        'powershell/public/services/graph/Invoke-MtGraphRequest.ps1'
        'powershell/internal/services/graph/Invoke-MtGraphRequestCache.ps1'
        'powershell/internal/services/entra/Get-MtDirectoryRoleAssignment.ps1'
        'powershell/public/services/entra/Get-MtConditionalAccessPolicy.ps1'
        'powershell/internal/services/global-secure-access/Get-MtPrivateAccessApplication.ps1'
        'powershell/internal/services/defender/Get-MdeConfiguration.ps1'
        'powershell/internal/services/github/Invoke-MtGitHubRequest.ps1'
    )

    # The one place a bare -DisableCache switch is passed: Invoke-MtGraphRequest reads nextLink pages without the
    # cache because skip tokens are not always unique, then caches the whole result.
    $script:AllowedBareSwitchFiles = @(
        'powershell/public/services/graph/Invoke-MtGraphRequest.ps1'
    )

    $searchRoots = @('tests', 'packs', 'powershell/public', 'powershell/internal') |
        ForEach-Object { Join-Path $repoRoot $_ } |
        Where-Object { Test-Path $_ }

    $script:ScriptFiles = foreach ($file in Get-ChildItem -Path $searchRoots -Filter '*.ps1' -Recurse -File) {
        $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
        @{
            Path         = $file.FullName
            RelativePath = $relativePath
            Allowed      = $relativePath -in $script:AllowedFiles
            AllowBare    = $relativePath -in $script:AllowedBareSwitchFiles
        }
    }
}

BeforeAll {
    function Get-DisableCacheUsage {
        param([string]$Path)

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)

        $mentions = @($tokens | Where-Object {
                $_.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment -and
                $_.Text -match 'DisableCache'
            } | ForEach-Object { $_.Extent.StartLineNumber } | Sort-Object -Unique)

        $bareSwitches = @($ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.CommandParameterAst] -and
                    $args[0].ParameterName -eq 'DisableCache' -and
                    $null -eq $args[0].Argument
                }, $true) | ForEach-Object { $_.Extent.StartLineNumber })

        [pscustomobject]@{
            Mentions     = $mentions
            BareSwitches = $bareSwitches
        }
    }
}

Describe 'Graph cache usage in Maester runs' {
    It '<RelativePath> does not use DisableCache' -ForEach ($script:ScriptFiles | Where-Object { -not $_.Allowed }) {
        $usage = Get-DisableCacheUsage -Path $Path
        $usage.Mentions | Should -BeNullOrEmpty -Because (
            "checks report on one snapshot of the tenant and must read through the session cache. Remove DisableCache " +
            "from line(s) $($usage.Mentions -join ', '), or, for a transport helper that only offers the switch to " +
            "callers, add the file to the allow list in GraphCacheUsage.Tests.ps1.")
    }

    It '<RelativePath> only forwards DisableCache' -ForEach ($script:ScriptFiles | Where-Object { $_.Allowed -and -not $_.AllowBare }) {
        $usage = Get-DisableCacheUsage -Path $Path
        $usage.BareSwitches | Should -BeNullOrEmpty -Because (
            "this helper may pass on its caller's choice (-DisableCache:`$DisableCache) but must not turn the cache " +
            "off itself (line(s) $($usage.BareSwitches -join ', ')).")
    }
}
