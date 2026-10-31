BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    # Files that may declare or forward a cache switch (DisableCache, NoCache, ClearCache) or define a Clear-Mt*Cache
    # command. They offer it to callers; nothing in a Maester run passes it. Checks report on one snapshot of the
    # tenant, so every check and helper reads through the session cache.
    $script:AllowedFiles = @(
        'powershell/public/services/graph/Invoke-MtGraphRequest.ps1'
        'powershell/internal/services/graph/Invoke-MtGraphRequestCache.ps1'
        'powershell/internal/services/entra/Get-MtDirectoryRoleAssignment.ps1'
        'powershell/public/services/entra/Get-MtConditionalAccessPolicy.ps1'
        'powershell/internal/services/global-secure-access/Get-MtPrivateAccessApplication.ps1'
        'powershell/internal/services/defender/Get-MdeConfiguration.ps1'
        'powershell/internal/services/github/Invoke-MtGitHubRequest.ps1'
        'powershell/public/services/sharepoint/Get-MtSpo.ps1'
        'powershell/public/connect/Clear-MtGraphCache.ps1'
        'powershell/public/connect/Clear-MtExoCache.ps1'
        'powershell/public/connect/Clear-MtADCache.ps1'
        'powershell/public/connect/Clear-MtDnsCache.ps1'
        # Session lifecycle, not a check: disconnecting and resetting the module clear the caches.
        'powershell/public/connect/Disconnect-Maester.ps1'
        'powershell/internal/session/Clear-ModuleVariable.ps1'
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
            IsCheck      = $relativePath -like 'tests/*' -or $relativePath -like 'packs/*'
        }
    }
}

BeforeAll {
    function Get-CacheBypass {
        param([string]$Path)

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
        $textKinds = @(
            [System.Management.Automation.Language.TokenKind]::Comment
            [System.Management.Automation.Language.TokenKind]::StringLiteral
            [System.Management.Automation.Language.TokenKind]::StringExpandable
            [System.Management.Automation.Language.TokenKind]::HereStringLiteral
            [System.Management.Automation.Language.TokenKind]::HereStringExpandable
        )

        # A cache switch as a parameter, argument, variable or splat key; text in comments and messages is ignored.
        $switches = @($tokens | Where-Object {
                $_.Kind -notin $textKinds -and $_.Text -match '(?i)DisableCache|NoCache|ClearCache'
            } | ForEach-Object { $_.Extent.StartLineNumber })

        # A call to a Clear-Mt*Cache command.
        $clearCommands = @($ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                    $args[0].GetCommandName() -match '^Clear-Mt\w*Cache$'
                }, $true) | ForEach-Object { $_.Extent.StartLineNumber })

        # -DisableCache with no argument, or with $true.
        $forcedSwitches = @($ast.FindAll({
                    $node = $args[0]
                    $node -is [System.Management.Automation.Language.CommandParameterAst] -and
                    $node.ParameterName -eq 'DisableCache' -and
                    ($null -eq $node.Argument -or $node.Argument.Extent.Text -eq '$true')
                }, $true) | ForEach-Object { $_.Extent.StartLineNumber })

        # An assignment to, or Clear()/Remove() on, a session cache: $__MtSession.GraphCache = @{}, or an entry
        # in one: $__MtSession.GraphCache[$key] = $value.
        $isSessionCache = {
            param($expression)
            while ($expression -is [System.Management.Automation.Language.IndexExpressionAst]) { $expression = $expression.Target }
            $expression -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $expression.Expression.Extent.Text -eq '$__MtSession' -and
            $expression.Member.Extent.Text -like '*Cache'
        }
        $sessionCacheWrites = @($ast.FindAll({
                    $node = $args[0]
                    ($node -is [System.Management.Automation.Language.AssignmentStatementAst] -and (& $isSessionCache $node.Left)) -or
                    ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                        $node.Member.Extent.Text -in 'Clear', 'Remove' -and (& $isSessionCache $node.Expression))
                }, $true) | ForEach-Object { $_.Extent.StartLineNumber })

        [pscustomobject]@{
            Switches           = $switches
            ClearCommands      = $clearCommands
            ForcedSwitches     = $forcedSwitches
            SessionCacheWrites = $sessionCacheWrites
        }
    }
}

Describe 'Cache usage in Maester runs' {
    It '<RelativePath> does not bypass the cache' -ForEach ($script:ScriptFiles | Where-Object { -not $_.Allowed }) {
        $usage = Get-CacheBypass -Path $Path
        $lines = @($usage.Switches) + @($usage.ClearCommands) | Sort-Object -Unique
        $lines | Should -BeNullOrEmpty -Because (
            "checks report on one snapshot of the tenant and must read through the session cache. Remove the cache " +
            "switch or Clear-Mt*Cache call on line(s) $($lines -join ', '), or, for a transport helper that only offers " +
            "the switch to callers, add the file to the allow list in GraphCacheUsage.Tests.ps1.")
    }

    It '<RelativePath> only forwards DisableCache' -ForEach ($script:ScriptFiles | Where-Object { $_.Allowed -and -not $_.AllowBare }) {
        $usage = Get-CacheBypass -Path $Path
        $usage.ForcedSwitches | Should -BeNullOrEmpty -Because (
            "this helper may pass on its caller's choice (-DisableCache:`$DisableCache) but must not turn the cache " +
            "off itself (line(s) $($usage.ForcedSwitches -join ', ')).")
    }

    It '<RelativePath> does not reset a session cache' -ForEach ($script:ScriptFiles | Where-Object { $_.IsCheck }) {
        $usage = Get-CacheBypass -Path $Path
        $usage.SessionCacheWrites | Should -BeNullOrEmpty -Because (
            "a check must not clear or edit `$__MtSession caches (line(s) $($usage.SessionCacheWrites -join ', ')).")
    }
}
