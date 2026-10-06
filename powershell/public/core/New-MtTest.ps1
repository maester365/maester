function New-MtTest {
    <#
    .SYNOPSIS
    Creates a new Maester native test: Test.<ID>.ps1 and Test.<ID>.md.

    .DESCRIPTION
    Writes a test function with its [MaesterTest] attribute and a Markdown file with the description,
    remediation and result sections. Run it with Invoke-MtTest -Path, and validate it with Get-MtTest -Path.

    .PARAMETER Id
    The test ID. Use your own prefix, for example CONTOSO.1001.

    .PARAMETER Title
    The one-line title shown in the report.

    .PARAMETER Severity
    Critical, High, Medium, Low or Info.

    .PARAMETER Service
    The services the test needs, for example Graph or ExchangeOnline.

    .PARAMETER Category
    The report grouping. Defaults to Custom.

    .PARAMETER Path
    The folder to create the files in. Defaults to ./Custom.

    .PARAMETER Force
    Overwrites existing files.

    .EXAMPLE
    New-MtTest -Id CONTOSO.1001 -Title 'Guest invitations are restricted' -Service Graph -Severity High

    Creates Custom/Test.CONTOSO.1001.ps1 and Custom/Test.CONTOSO.1001.md.

    .LINK
    https://maester.dev/docs/commands/New-MtTest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Id,

        [Parameter(Mandatory)]
        [string] $Title,

        [Parameter()]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')]
        [string] $Severity = 'Medium',

        [Parameter()]
        [string[]] $Service = @('Graph'),

        [Parameter()]
        [string] $Category = 'Custom',

        [Parameter()]
        [string] $Path = './Custom',

        [Parameter()]
        [switch] $Force
    )

    $schema = Get-MtTestSchema
    if ($Id -notmatch $schema.IdPattern -or $Id.Length -gt $schema.IdMaxLength) {
        Write-Error "'$Id' is not a valid test ID. Use letters and digits separated by dots or dashes, for example CONTOSO.1001."
        return
    }
    if ($Title -match '[\r\n]') { Write-Error 'The title must be one line.'; return }
    foreach ($s in $Service) {
        if ($s -ne 'None' -and -not (Resolve-MtServiceName -Name $s)) { Write-Warning "Service '$s' is not in the service registry; the test will be skipped as ServiceNotRegistered." }
    }
    if ($schema.ReservedPrefixes | Where-Object { $Id.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) {
        Write-Warning "The prefix of '$Id' belongs to the tests shipped with Maester. Use your own prefix, for example CONTOSO."
    }

    $functionName = 'Test-' + (($Id -split '[.\-_]' | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '')
    $escape = { param($v) $v.Replace("'", "''") }
    $serviceList = if ($Service.Count -eq 1) { "'$(& $escape $Service[0])'" } else { "(" + (($Service | ForEach-Object { "'$(& $escape $_)'" }) -join ', ') + ")" }

    $ps1 = @"
function $functionName {
    <#
    .SYNOPSIS
    $Title
    #>
    [MaesterTest(
        Id       = '$(& $escape $Id)',
        Title    = '$(& $escape $Title)',
        Severity = '$Severity',
        Category = '$(& $escape $Category)',
        Service  = $serviceList
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Read the tenant state. The engine has already checked that the services above are connected,
    # and turns an uncaught error into an Error result, so no connection check or try/catch is needed.
    `$settings = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy'

    `$passed = `$null -ne `$settings

    `$resultMarkdown = if (`$passed) { 'Well done. The tenant meets this requirement.' } else { 'The tenant does not meet this requirement.' }
    Add-MtTestResultDetail -Result `$resultMarkdown

    return `$passed
}
"@
    $md = @"
Describe what this test checks and why it matters.

#### Remediation action

Explain how to fix a failing result, step by step.

#### Related links

- [Microsoft Learn](https://learn.microsoft.com)

<!--- Results --->
%TestResult%
"@

    $null = New-Item -Path $Path -ItemType Directory -Force -WhatIf:$false
    $ps1Path = Join-Path $Path "Test.$Id.ps1"
    $mdPath = Join-Path $Path "Test.$Id.md"
    foreach ($target in @(@{ Path = $ps1Path; Content = $ps1 }, @{ Path = $mdPath; Content = $md })) {
        if ((Test-Path -LiteralPath $target.Path) -and -not $Force) {
            Write-Error "$($target.Path) already exists. Use -Force to overwrite it."
            return
        }
    }
    foreach ($target in @(@{ Path = $ps1Path; Content = $ps1 }, @{ Path = $mdPath; Content = $md })) {
        if ($PSCmdlet.ShouldProcess($target.Path, 'Create test file')) {
            Set-Content -LiteralPath $target.Path -Value $target.Content -Encoding utf8
            Get-Item -LiteralPath $target.Path
        }
    }
}
