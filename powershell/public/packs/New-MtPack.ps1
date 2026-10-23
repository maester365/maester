function New-MtPack {
    <#
    .SYNOPSIS
    Creates a new Maester Pack folder: maester-pack.json, a suite with a first test, and optionally a connector.

    .DESCRIPTION
    A pack is a folder, usually a GitHub repository, that others install with Install-MtPack. This
    writes its manifest, a README, a tests folder with suite.json and a first test MP.<Code>.1001, and with
    -Connector a connector for a service of your own and a helper that reads its connection.

    Check it with Test-MtPack, and run its tests with Invoke-MtTest -Path. Publish it by pushing the folder
    to GitHub under the publisher's account and creating a release.

    .PARAMETER Path
    The folder to create. It must be empty or not exist.

    .PARAMETER Id
    The pack ID, '<publisher>.<name>' in lower case, for example contoso.google-workspace. The publisher
    is the GitHub user or organisation that will own the pack's repository.

    .PARAMETER Code
    The pack's code, which starts every test ID of the pack: CONTOSO for MP.CONTOSO.1001. Two to ten letters or
    digits, starting with a letter. A publisher with several packs can group them with up to three parts
    separated by dots, such as CNT.GWS for MP.CNT.GWS.1001. No two installed packs may share a code, or have
    one code that starts with the other.

    .PARAMETER Name
    The pack's display name. By default made from its ID.

    .PARAMETER Connector
    Also write a connector, so the pack can connect to a service Maester does not know.

    .EXAMPLE
    New-MtPack -Path ./maester-google-workspace -Id contoso.google-workspace -Code CNT -Connector

    Creates a pack with a connector for the service CNT.GoogleWorkspace.

    .LINK
    https://maester.dev/docs/commands/New-MtPack
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo], [object[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?\.[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$')]
        [string] $Id,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}(\.[A-Za-z][A-Za-z0-9]{1,9}){0,2}$')]
        [string] $Code,

        [Parameter()]
        [string] $Name,

        [Parameter()]
        [switch] $Connector
    )

    Write-Verbose "New-MtPack: Path=$Path Id=$Id Code=$Code"

    $Code = $Code.ToUpperInvariant()
    $publisher, $short = $Id.Split('.', 2)
    $pascal = ($short -split '-' | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join ''
    # Function names take the code without its dots: CNT.GWS gives Connect-CntGws<Name>.
    $prefix = ($Code.Split('.') | ForEach-Object { $_.Substring(0, 1) + $_.Substring(1).ToLowerInvariant() }) -join ''
    if (-not $Name) { $Name = ($short -split '-' | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join ' ' }
    $reserved = Test-MtPackReservedName -Code $Code
    if ($reserved) { throw $reserved }
    if ((Test-Path -LiteralPath $Path) -and @(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) { throw "The folder '$Path' is not empty." }

    $service = "$Code.$pascal"
    # The pack needs at least the Maester it was made with. A source checkout says 3.0.0 until a release sets the
    # version, so a fixed '>=3.1' would make a new pack refuse to run on the build it was written against.
    $moduleVersion = $ExecutionContext.SessionState.Module.Version
    $manifest = [ordered]@{
        '$schema'       = 'https://maester.dev/schemas/maester-pack-1.0.json'
        Id              = $Id
        Name            = $Name
        Description     = "Checks for $Name."
        Version         = '0.1.0'
        Publisher       = $publisher
        License         = 'MIT'
        RequiresMaester = ">=$($moduleVersion.Major).$($moduleVersion.Minor)"
        Code            = $Code
        Suites          = @('tests')
    }
    if ($Connector) {
        $manifest.Helpers = @('helpers')
        $manifest.Connectors = @([ordered]@{
                Service     = $service
                DisplayName = $Name
                File        = "connector/Connect-$prefix$pascal.ps1"
                Connect     = "Connect-$prefix$pascal"
                Test        = "Test-$prefix$pascal"
                Disconnect  = "Disconnect-$prefix$pascal"
            })
    }
    $manifest.Uses = [ordered]@{ Services = @($(if ($Connector) { $service } else { 'Graph' })); GraphScopes = @(); Network = @(); Modules = @() }

    $files = [ordered]@{
        'maester-pack.json' = ($manifest | ConvertTo-Json -Depth 6)
        'README.md'         = @"
# $Name

A [Maester Pack](https://maester.dev/docs/packs). Install it with:

``````powershell
Install-MtPack $publisher/<repository>
``````

## Tests

| ID | Title |
| --- | --- |
| MP.$Code.1001 | Replace with your first check |
"@
        'tests/suite.json'  = ([ordered]@{ Id = "$Code.$pascal"; Name = $Name } | ConvertTo-Json)
    }
    if ($Connector) {
        $files["connector/Connect-$prefix$pascal.ps1"] = @"
function Connect-$prefix$pascal {
    <#
    .SYNOPSIS
    Connects to $Name. Connect-Maester -Service $service calls it; its parameters come from -ServiceSetting,
    from Connections.$service in maester-config.json, or from MAESTER_$($service.ToUpperInvariant() -replace '[^A-Z0-9]', '_')_<NAME> environment variables.
    #>
    [CmdletBinding()]
    param(
        [string] `$Domain
    )

    # Sign in here and keep what the tests need. Maester keeps it for this PowerShell session only.
    Set-MtConnectionState -Value @{ Domain = `$Domain } -Tenant `$Domain
}

function Test-$prefix$pascal {
    <#
    .SYNOPSIS
    Returns `$true when $Name is connected. The tests that need $service are skipped otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    [bool](Get-MtConnectionState)
}

function Disconnect-$prefix$pascal {
    <#
    .SYNOPSIS
    Disconnects from $Name.
    #>
    [CmdletBinding()]
    param()

    Clear-MtConnectionState
}
"@
        $files["helpers/Get-$prefix$($pascal)Setting.ps1"] = @"
function Get-$prefix$($pascal)Setting {
    <#
    .SYNOPSIS
    Returns the settings the tests check, read through the connection that Connect-$prefix$pascal made.
    #>
    [CmdletBinding()]
    param()

    `$connection = Get-MtConnectionState
    # Call the service's API with what the connection holds.
    @{ Domain = `$connection.Domain }
}
"@
    }

    foreach ($relative in $files.Keys) {
        $target = Join-Path $Path $relative
        if (-not $PSCmdlet.ShouldProcess($target, 'Create pack file')) { continue }
        $null = New-Item -Path (Split-Path -Path $target -Parent) -ItemType Directory -Force
        Set-Content -LiteralPath $target -Value $files[$relative] -Encoding utf8
        Get-Item -LiteralPath $target
    }
    $testService = if ($Connector) { $service } else { 'Graph' }
    $testFolder = Join-Path $Path 'tests'
    if (-not $PSCmdlet.ShouldProcess($testFolder, 'Create the first test')) { return }
    # The connector's service is not registered until the pack is installed, so New-MtTest's warning about it is expected.
    $created = @(New-MtTest -Id "MP.$Code.1001" -Title 'Replace with your first check' -Service $testService -Path $testFolder -WarningAction SilentlyContinue)
    $testScript = $created | Where-Object Extension -EQ '.ps1' | Select-Object -First 1
    if ($Connector -and $testScript) {
        $text = [System.IO.File]::ReadAllText($testScript.FullName)
        $text = $text.Replace("Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy'", "Get-$prefix$($pascal)Setting")
        [System.IO.File]::WriteAllText($testScript.FullName, $text, [System.Text.UTF8Encoding]::new($false))
    }
    $created
}
