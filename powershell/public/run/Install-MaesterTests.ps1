function Install-MaesterTests {
    <#
    .SYNOPSIS
    Not needed from Maester 3.0. Prepares a folder for your own Maester tests and configuration.

    .DESCRIPTION
    From Maester 3.0 the tests that ship with Maester run from the module itself, so updating the module
    updates them, and Maester needs no tests folder or repository: Invoke-Maester runs the built-in tests
    from any folder. You can remove Install-MaesterTests from your scripts and pipelines.

    It is kept so that existing scripts keep working. It writes custom/README.md and a starter
    maester-config.json when they are missing. It never writes a test file and never overwrites an
    existing file, so it is safe to call on every pipeline run.

    To add your own tests, run New-MtTest, which creates the custom folder. To change settings, create a
    maester-config.json with only the settings you change. Run Invoke-Maester -Path <folder> to run the
    built-in tests together with the custom tests and config in that folder.

    .PARAMETER Path
    The folder to prepare. Defaults to the current directory.

    .PARAMETER SkipPesterCheck
    No longer has any effect. Maester 3.0 does not install Pester; install it yourself only if you run
    Pester-format custom tests.

    .EXAMPLE
    Install-MaesterTests -Path ./maester

    Creates ./maester with custom/README.md and maester-config.json.

    .LINK
    https://maester.dev/docs/commands/Install-MaesterTests
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Kept for compatibility with Maester 2.x')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SkipPesterCheck', Justification = 'Kept for compatibility with Maester 2.x')]
    [CmdletBinding()]
    param(
        # The folder to prepare. Defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [string] $Path = '.',

        # No longer has any effect. Kept so that existing scripts keep working.
        [Parameter(Mandatory = $false)]
        [switch] $SkipPesterCheck
    )

    Get-IsNewMaesterVersionAvailable | Out-Null

    $templates = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/templates'
    # Reuse an existing custom folder whatever its case (2.x created 'Custom'); new folders are lowercase.
    $existing = Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq 'custom' } | Select-Object -First 1
    $customFolder = if ($existing) { $existing.FullName } else { Join-Path $Path 'custom' }
    $null = New-Item -Path $customFolder -ItemType Directory -Force

    $written = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(
            @{ Source = Join-Path $templates 'custom/README.md'; Target = Join-Path $customFolder 'README.md' }
            @{ Source = Join-Path $templates 'maester-config.json'; Target = Join-Path $Path 'maester-config.json' }
        )) {
        if (-not (Test-Path -LiteralPath $file.Target)) {
            Copy-Item -LiteralPath $file.Source -Destination $file.Target
            $written.Add($file.Target)
        }
    }
    foreach ($w in $written) { Write-Verbose "Created $w" }

    $staleCopies = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/][Cc]ustom[\\/]' })
    if ($staleCopies.Count -gt 0) {
        Write-Host "This folder has $($staleCopies.Count) test file(s) outside custom/. Copies of the built-in tests are no longer needed; run Update-MaesterTests -Path '$Path' to remove them." -ForegroundColor Yellow
    }

    $message = 'Run Connect-Maester to sign in and then run Invoke-Maester to start testing.'
    if (Test-MtConnection Graph) {
        $message = 'Run Invoke-Maester to start testing.'
    }
    Write-Host "Maester is ready. The built-in tests run from the module; put your own tests in $customFolder.`n$message" -ForegroundColor Green
    Write-Host 'Install-MaesterTests is no longer needed: Invoke-Maester runs the built-in tests from any folder. See https://maester.dev/docs/upgrading-from-2x' -ForegroundColor DarkGray
}
