function New-MtTest {
    <#
    .SYNOPSIS
    Creates a new Maester native test: Test.<ID>.ps1 and Test.<ID>.md.

    .DESCRIPTION
    Writes a test function with its [MaesterTest] attribute and a Markdown file with the description,
    remediation and result sections. Run it with Invoke-MtTest -Path, and validate it with Get-MtTest -Path.

    A custom test needs only an ID and a title. -Product, -Feature, -Area, -ResourceType, -UserImpact,
    -ImplementationCost and -Mitre fill in the attributes that say what the test is about, what to fix first
    and which attack techniques it addresses; add or change them in the file later as you like.

    .PARAMETER Id
    The test ID. Use your own prefix, for example CONTOSO.1001.

    .PARAMETER Title
    The one-line title shown in the report.

    .PARAMETER Severity
    Critical, High, Medium, Low or Info.

    .PARAMETER Service
    The services the test needs, for example Graph or ExchangeOnline.

    .PARAMETER Product
    The product where the fix is made: a key of the Maester taxonomy such as entra or exchange (an alias such as
    'Entra ID' is written as the key), or any name of your own. Groups the console progress and the run summary.

    .PARAMETER Feature
    The part of the product the test is about, for example conditional-access. With a Maester product, one of
    its feature keys; otherwise any text.

    .PARAMETER Area
    The security theme, for example authentication or privileged-access.

    .PARAMETER ResourceType
    What a failing result points at, for example Tenant or User.

    .PARAMETER UserImpact
    How much the recommended fix disrupts end users: Low, Medium or High.

    .PARAMETER ImplementationCost
    How much administrator work the recommended fix takes: Low, Medium or High.

    .PARAMETER Mitre
    The MITRE ATT&CK technique IDs the checked control prevents or detects, for example T1110.003, or None.

    .PARAMETER Setting
    Shared settings the test receives as parameters, for example EmergencyAccessAccounts or ParkedDomains. Each
    becomes a parameter bound to the setting with [MaesterParameter(Setting = '...')], with the type, default and
    allowed values of the settings registry. An administrator sets the value once under GlobalSettings in
    maester-config.json, and the test's TestSettings row can override it. Get-MtSetting -Name completes the names.

    .PARAMETER Path
    The folder to create the files in. Defaults to ./custom (an existing ./Custom folder is reused).

    .PARAMETER Force
    Overwrites existing files.

    .EXAMPLE
    New-MtTest -Id CONTOSO.1001 -Title 'Guest invitations are restricted' -Service Graph -Severity High

    Creates custom/Test.CONTOSO.1001.ps1 and custom/Test.CONTOSO.1001.md.

    .EXAMPLE
    New-MtTest -Id CONTOSO.1002 -Title 'Legacy authentication is blocked' -Product entra -Feature conditional-access -Area authentication -ResourceType Tenant -Severity High -UserImpact Medium -ImplementationCost Low -Mitre T1110.003

    Creates a test with the classification, priority and ATT&CK attributes filled in. The attribute rubric at
    https://maester.dev/docs/writing-tests/attribute-rubric explains how to choose each value.

    .EXAMPLE
    New-MtTest -Id CONTOSO.1003 -Title 'Break glass accounts have a passkey' -Setting EmergencyAccessAccounts

    Creates a test with an EmergencyAccessAccounts parameter that the engine fills from the setting of that name.

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
        [string] $Product,

        [Parameter()]
        [string] $Feature,

        [Parameter()]
        [string] $Area,

        [Parameter()]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')]
        [string] $ResourceType,

        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High')]
        [string] $UserImpact,

        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High')]
        [string] $ImplementationCost,

        [Parameter()]
        [ValidatePattern('^(T[0-9]{4}(\.[0-9]{3})?|None)$')]
        [string[]] $Mitre,

        [Parameter()]
        [string[]] $Setting,

        [Parameter()]
        [string] $Path = './custom',

        [Parameter()]
        [switch] $Force
    )

    if (-not $PSBoundParameters.ContainsKey('Path')) {
        # Reuse an existing custom folder whatever its case (2.x created 'Custom').
        $existing = Get-ChildItem -LiteralPath (Get-Location).Path -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq 'custom' } | Select-Object -First 1
        if ($existing) { $Path = $existing.FullName }
    }
    Write-Verbose "New-MtTest: $Id in $Path"
    $schema = Get-MtTestSchema
    if ($Id -notmatch $schema.IdPattern -or $Id.Length -gt $schema.IdMaxLength) {
        Write-Error "'$Id' is not a valid test ID. Use letters and digits separated by dots or dashes, for example CONTOSO.1001."
        return
    }
    if ($Title -match '[\r\n]') { Write-Error 'The title must be one line.'; return }
    foreach ($text in @(@{ Name = 'Product'; Value = $Product; Max = 40 }, @{ Name = 'Feature'; Value = $Feature; Max = 60 }, @{ Name = 'Area'; Value = $Area; Max = 60 })) {
        if ($text.Value -match '[\r\n]' -or "$($text.Value)".Length -gt $text.Max) { Write-Error "-$($text.Name) must be one line of at most $($text.Max) characters."; return }
    }
    if ($Mitre -contains 'None' -and @($Mitre).Count -gt 1) { Write-Error '-Mitre is either a list of technique IDs or None.'; return }
    # A value the taxonomy registry knows is written as its key.
    $taxonomy = Get-MtTaxonomy
    $productKey = if ($Product) { Resolve-MtProductKey -Name $Product -Taxonomy $taxonomy }
    if ($productKey) { $Product = $productKey }
    $entry = $null
    if ($productKey -and $Feature -and $taxonomy.Lookup.Feature[$productKey].TryGetValue($Feature, [ref] $entry)) { $Feature = $entry.Key }
    if ($Area -and $taxonomy.Lookup.Area.TryGetValue($Area, [ref] $entry)) { $Area = $entry.Key }
    if ($ResourceType -and $taxonomy.Lookup.ResourceType.TryGetValue($ResourceType, [ref] $entry)) { $ResourceType = $entry.Key }
    foreach ($s in $Service) {
        if ($s -ne 'None' -and -not (Resolve-MtServiceName -Name $s)) { Write-Warning "Service '$s' is not in the service registry; the test will be skipped as ServiceNotRegistered." }
    }
    if ($schema.ReservedPrefixes | Where-Object { $Id.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) {
        Write-Warning "The prefix of '$Id' is reserved for tests shipped with Maester and for Maester Packs. Use your own prefix, for example CONTOSO."
    }

    # One parameter per shared setting, with the type, default and allowed values of the settings registry.
    $quoteValue = { param($v) "'" + ([string]$v).Replace("'", "''") + "'" }
    $registry = (Get-MtSettingRegistry).Settings
    $parameterBlocks = foreach ($name in @($Setting | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not $registry.ContainsKey($name)) {
            Write-Error "'$name' is not a registered setting. The settings are listed at https://maester.dev/docs/configuration/run-configuration#globalsettings. Add a parameter for a setting of your own by hand: [MaesterParameter(Setting = 'Contoso.Key')]."
            return
        }
        $entry = $registry[$name]
        $registeredName = @($registry.Keys | Where-Object { $_ -eq $name })[0]
        if ($entry.Type -eq 'object' -or ($entry.ContainsKey('Role') -and $entry.Role -eq 'Connection')) {
            Write-Error "'$registeredName' is a connection setting, which a test does not receive as a parameter."
            return
        }
        $default = switch ($entry.Type) {
            'int' { [string][int]$entry.Default }
            'bool' { if ($entry.Default) { '$true' } else { '$false' } }
            'string' { & $quoteValue $entry.Default }
            'string[]' { '@(' + ((@($entry.Default) | Where-Object { $null -ne $_ } | ForEach-Object { & $quoteValue $_ }) -join ', ') + ')' }
            default { '@()' }
        }
        $lines = @("        # $($entry.Description)", "        [MaesterParameter(Setting = '$registeredName')]")
        if ($entry.ContainsKey('AllowedValues') -and $entry.AllowedValues) { $lines += "        [ValidateSet($((@($entry.AllowedValues) | ForEach-Object { & $quoteValue $_ }) -join ', '))]" }
        $lines += "        [$($entry.Type)] `$$(@($registeredName -split '\.')[-1]) = $default"
        $lines -join "`n"
    }
    $paramBlock = if (@($parameterBlocks).Count -gt 0) { "param(`n" + (@($parameterBlocks) -join ",`n`n") + "`n    )" } else { 'param()' }

    $functionName = 'Test-' + (($Id -split '[.\-_]' | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '')
    # The attribute, in the order of the design: identity, classification, priority, mappings, applicability.
    $quote = { param($v) "'" + ([string]$v).Replace("'", "''") + "'" }
    $list = { param($values) if (@($values).Count -eq 1) { & $quote @($values)[0] } else { '(' + ((@($values) | ForEach-Object { & $quote $_ }) -join ', ') + ')' } }
    $properties = [ordered]@{ Id = & $quote $Id; Title = & $quote $Title }
    if ($Product) { $properties.Product = & $quote $Product }
    if ($Feature) { $properties.Feature = & $quote $Feature }
    if ($Area) { $properties.Area = & $quote $Area }
    if ($ResourceType) { $properties.ResourceType = & $quote $ResourceType }
    $properties.Severity = & $quote $Severity
    if ($UserImpact) { $properties.UserImpact = & $quote $UserImpact }
    if ($ImplementationCost) { $properties.ImplementationCost = & $quote $ImplementationCost }
    if ($Mitre) { $properties.Mitre = & $list $Mitre }
    $properties.Service = & $list $Service
    $width = ($properties.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $attributeLines = ($properties.GetEnumerator() | ForEach-Object { "        $($_.Key.PadRight($width)) = $($_.Value)" }) -join ",`n"

    $ps1 = @"
function $functionName {
    <#
    .SYNOPSIS
    $Title
    #>
    [MaesterTest(
$attributeLines
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    $paramBlock

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
    # PowerShell files are UTF-8 with a byte order mark (see the contributing guide); Markdown has none.
    foreach ($target in @(@{ Path = $ps1Path; Content = $ps1; Encoding = 'utf8BOM' }, @{ Path = $mdPath; Content = $md; Encoding = 'utf8NoBOM' })) {
        if ($PSCmdlet.ShouldProcess($target.Path, 'Create test file')) {
            Set-Content -LiteralPath $target.Path -Value $target.Content -Encoding $target.Encoding
            Get-Item -LiteralPath $target.Path
        }
    }
}
