function Install-MaesterTests {
    <#
    .SYNOPSIS
    Prepares a folder for your own Maester tests and configuration.

    .DESCRIPTION
    From Maester 3.0 the tests that ship with Maester run from the module itself, so updating the module
    updates them and nothing needs to be copied. Install-MaesterTests prepares a folder for your custom
    tests and configuration: it writes Custom/README.md and a starter maester-config.json when they are
    missing. It never writes a test file and never overwrites an existing file, so it is safe to call
    on every pipeline run.

    Run Invoke-Maester -Path <folder> to run the built-in tests together with the custom tests in it.

    .PARAMETER Path
    The folder to prepare. Defaults to the current directory.

    .PARAMETER SkipPesterCheck
    No longer has any effect. Maester 3.0 does not install Pester; install it yourself only if you run
    Pester-format custom tests.

    .EXAMPLE
    Install-MaesterTests -Path ./maester-tests

    Creates ./maester-tests with Custom/README.md and maester-config.json.

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
    $customFolder = Join-Path $Path 'Custom'
    $null = New-Item -Path $customFolder -ItemType Directory -Force

    $written = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(
            @{ Source = Join-Path $templates 'Custom/README.md'; Target = Join-Path $customFolder 'README.md' }
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
        Write-Host "This folder has $($staleCopies.Count) test file(s) outside Custom/. Copies of the built-in tests are no longer needed; run Update-MaesterTests -Path '$Path' to remove them." -ForegroundColor Yellow
    }

    $message = 'Run Connect-Maester to sign in and then run Invoke-Maester to start testing.'
    if (Test-MtConnection Graph) {
        $message = 'Run Invoke-Maester to start testing.'
    }
    Write-Host "Maester is ready. The built-in tests run from the module; put your own tests in $customFolder.`n$message" -ForegroundColor Green
}
