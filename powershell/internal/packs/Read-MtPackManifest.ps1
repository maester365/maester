function Read-MtPackManifest {
    <#
    .SYNOPSIS
    Reads and validates a pack's maester-pack.json (Maester Packs design, section 4.2).

    .DESCRIPTION
    The manifest is static data: nothing in it runs. Returns Manifest (the parsed object, with Code in
    capitals and every list present), Errors and Warnings. An error has a Code and a Message; a pack with
    an error is not installed and does not load.

    - An unknown top-level key is a warning, as for suite.json. An unknown key inside Uses, Connectors,
      Requires, Permissions or Runtime is an error, because those keys describe what the pack can reach and
      leaving one out would hide it from the install prompt.
    - Runtime other than Script is refused with RuntimeNotSupported: packs in other languages (section 4.8)
      need a newer Maester. Catalog, a JSON file in the pack that lists its tests, is read by listings only;
      the tests always come from Suites.
    - A module in Uses.Modules is pinned to one exact Version and saved by Maester (Install Maester, the
      default), or is the user's own install (Install User) that the pack runs in a child process (Process
      Child), never in Maester's: Maester then neither saves nor imports it, and it may name a MinimumVersion.
    - The pack's code and the connector service names are checked against the reserved list (section 4.6).
      -Official allows the names reserved for packs from the maester365 organisation. That two installed
      packs have different codes is checked by Test-MtPackCodeOverlap, at install and when packs load.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The pack folder (holding maester-pack.json) or the manifest file itself.
        [Parameter(Mandatory)]
        [string] $Path,

        # The pack is published by maester365 (a built-in pack, or one installed from the maester365 organisation).
        [Parameter()]
        [switch] $Official
    )

    $errors = [System.Collections.Generic.List[pscustomobject]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $fail = { param($message, $code = 'InvalidManifest') $errors.Add([pscustomobject]@{ Code = $code; Message = $message }) }
    $result = { param($manifest) [pscustomobject]@{ Manifest = $manifest; Errors = $errors.ToArray(); Warnings = $warnings.ToArray() } }

    $file = if (Test-Path -LiteralPath $Path -PathType Container) { Join-Path $Path 'maester-pack.json' } else { $Path }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        & $fail "There is no maester-pack.json in '$Path'."
        return & $result $null
    }
    try {
        $manifest = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        & $fail "maester-pack.json is not valid JSON: $($_.Exception.Message)"
        return & $result $null
    }
    if ($manifest -isnot [pscustomobject]) {
        & $fail 'maester-pack.json must hold one JSON object.'
        return & $result $null
    }

    $topLevel = @('$schema', 'Id', 'Guid', 'Name', 'Description', 'Version', 'Publisher', 'License', 'Homepage', 'Support', 'SecurityContact',
        'RequiresMaester', 'Code', 'Suites', 'Helpers', 'Connectors', 'Uses', 'Requires', 'Exports', 'Categories', 'Listed',
        'Deprecated', 'Yanked', 'Icon', 'EnabledByDefault', 'Runtime', 'Catalog', 'Pricing', 'Banner')
    $strictKeys = @{
        Uses        = @('Services', 'GraphScopes', 'TenantWrites', 'Network', 'Modules')
        Connector   = @('Service', 'Platform', 'DisplayName', 'File', 'Connect', 'Test', 'Disconnect', 'Describe', 'Renew', 'OptIn', 'Permissions', 'Environment')
        Requires    = @('Packs')
        RequiredPack = @('Source', 'Id', 'Version')
        Permissions = @('Role', 'Scopes')
        Module      = @('Name', 'Version', 'MinimumVersion', 'Install', 'Process')
    }
    $checkKeys = {
        param($object, $allowed, $where)
        foreach ($p in $object.PSObject.Properties) {
            if ($p.Name -notin $allowed) { & $fail "$where has the key '$($p.Name)', which this version of Maester does not know. It describes what the pack can reach, so the pack is refused; it may need a newer Maester." }
        }
    }
    $list = {
        param($name, $object = $manifest)
        $p = $object.PSObject.Properties[$name]
        # Callers collect the output with @(), so the items are written one by one.
        if (-not $p -or $null -eq $p.Value) { return }
        $p.Value
    }
    $text = { param($name) $p = $manifest.PSObject.Properties[$name]; if ($p -and $p.Value -is [string]) { $p.Value } else { $null } }

    foreach ($p in $manifest.PSObject.Properties) {
        if ($p.Name -notin $topLevel) { $warnings.Add("maester-pack.json has the unknown key '$($p.Name)', which is ignored.") }
    }

    # Packs in other languages (section 4.8) are refused cleanly rather than losing their tests.
    $runtime = $manifest.PSObject.Properties['Runtime']
    if ($runtime -and $null -ne $runtime.Value) {
        $kind = if ($runtime.Value -is [string]) { $runtime.Value } elseif ($runtime.Value.PSObject.Properties['Kind']) { [string]$runtime.Value.Kind } else { $null }
        if ($kind -ne 'Script') { & $fail "The pack's Runtime is '$kind'. This version of Maester runs only PowerShell (Script) packs; packs in other languages need a newer Maester." 'RuntimeNotSupported' }
        elseif ($runtime.Value -isnot [string]) { & $checkKeys $runtime.Value @('Kind') 'Runtime' }
    }
    if ($manifest.PSObject.Properties['Catalog'] -and $null -ne $manifest.Catalog) {
        if ($manifest.Catalog -isnot [string]) { & $fail 'The pack describes its tests with a Catalog object, which needs a newer version of Maester.' 'RuntimeNotSupported' }
        elseif (-not (Test-MtPackRelativePath -Path $manifest.Catalog)) { & $fail "Catalog must be a JSON file inside the pack; '$($manifest.Catalog)' is not one." }
    }

    # Identity.
    $id = & $text 'Id'
    $publisher = & $text 'Publisher'
    if (-not $id -or $id -cnotmatch '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?\.[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$') {
        & $fail "Id must be '<publisher>.<name>' in lower case, for example 'contoso.google-workspace'; it is '$id'."
    }
    if (-not $publisher) { & $fail 'Publisher is required: the GitHub user or organisation that owns the pack.' }
    elseif ($id -and $id.Split('.')[0] -ne $publisher.ToLowerInvariant() -and -not ($publisher -eq 'maester365' -and $id.Split('.')[0] -eq 'maester')) {
        & $fail "Id must start with the publisher: '$($publisher.ToLowerInvariant()).<name>'."
    }
    if ($id -and $id.Split('.')[0] -in 'maester', 'maester365' -and -not $Official) {
        & $fail "The publisher '$($id.Split('.')[0])' is reserved for packs from the maester365 organisation."
    }
    # The pack's GUID ties it to its entry in the pack registry (pack-registry/publishers/<publisher>.json).
    $guid = $manifest.PSObject.Properties['Guid']
    if ($guid -and $null -ne $guid.Value -and -not ($guid.Value -is [string] -and $guid.Value -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
        & $fail "Guid must be a GUID such as 'd1e2db80-6c27-4cb6-9389-2edf0a898d23'; it is '$($guid.Value)'."
    }
    foreach ($name in 'Name', 'Version') {
        if (-not (& $text $name)) { & $fail "$name is required." }
    }
    $version = & $text 'Version'
    if ($version -and $version -notmatch '^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$') { & $fail "Version must be a semantic version such as 1.2.0; it is '$version'." }
    $requires = & $text 'RequiresMaester'
    if ($requires -and -not (Test-MtVersionRange -Range $requires -Validate)) { & $fail "RequiresMaester '$requires' is not a version range such as '>=3.1 <4.0'." }

    # The pack's code (section 4.5): one to three dot-separated parts, so a publisher can group packs (CNT.GWS).
    $code = & $text 'Code'
    if (-not $code -or $code -notmatch '^[A-Za-z][A-Za-z0-9]{1,9}(\.[A-Za-z][A-Za-z0-9]{1,9}){0,2}$') {
        & $fail "Code must be one to three parts separated by dots, each two to ten letters or digits starting with a letter, for example 'ZTA' or 'CNT.GWS'; it is '$code'."
    } else {
        $code = $code.ToUpperInvariant()
        $manifest.Code = $code
        $reserved = Test-MtPackReservedName -Code $code -Official:$Official
        if ($reserved) { & $fail $reserved 'ReservedCode' }
    }

    # Folders: relative paths inside the pack.
    $folders = @{ Suites = @(& $list 'Suites'); Helpers = @(& $list 'Helpers') }
    foreach ($key in $folders.Keys) {
        foreach ($folder in $folders[$key]) {
            if ($folder -isnot [string] -or -not (Test-MtPackRelativePath -Path $folder)) { & $fail "$key must list folders inside the pack, such as 'tests'; '$folder' is not one." }
        }
    }

    # Connectors (section 6.1).
    $connectors = @(& $list 'Connectors')
    foreach ($c in $connectors) {
        if ($c -isnot [pscustomobject]) { & $fail 'Each entry of Connectors must be an object.'; continue }
        & $checkKeys $c $strictKeys.Connector "The connector '$($c.Service)'"
        foreach ($required in 'Service', 'File', 'Connect', 'Test') {
            if (-not ($c.PSObject.Properties[$required] -and $c.$required -is [string] -and $c.$required)) { & $fail "The connector '$($c.Service)' needs $required." }
        }
        if ($c.PSObject.Properties['File'] -and $c.File -is [string] -and -not (Test-MtPackRelativePath -Path $c.File)) { & $fail "The connector file '$($c.File)' must be a path inside the pack." }
        if ($c.PSObject.Properties['Service'] -and $c.Service -is [string]) {
            $problem = Test-MtPackReservedName -Service $c.Service -Code $code -Official:$Official
            if ($problem) { & $fail $problem 'ReservedService' }
        }
        if ($c.PSObject.Properties['Permissions'] -and $c.Permissions) { & $checkKeys $c.Permissions $strictKeys.Permissions "The Permissions of the connector '$($c.Service)'" }
        foreach ($fn in 'Connect', 'Test', 'Disconnect', 'Describe', 'Renew') {
            if ($c.PSObject.Properties[$fn] -and $c.$fn -and $c.$fn -notmatch '^[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*$') { & $fail "The connector '$($c.Service)' names '$($c.$fn)' as its $fn function, which is not a Verb-Noun function name." }
        }
    }
    if ($folders.Suites.Count -eq 0 -and $connectors.Count -eq 0) { & $fail 'The pack has no Suites and no Connectors, so it adds nothing.' }

    # What the pack reaches (section 4.2).
    $uses = $manifest.PSObject.Properties['Uses']
    if ($uses -and $null -ne $uses.Value) {
        if ($uses.Value -isnot [pscustomobject]) { & $fail 'Uses must be an object.' }
        else {
            & $checkKeys $uses.Value $strictKeys.Uses 'Uses'
            foreach ($m in @(& $list 'Modules' $uses.Value)) {
                if ($m -isnot [pscustomobject] -or -not $m.PSObject.Properties['Name']) { & $fail 'Each entry of Uses.Modules needs a Name.'; continue }
                & $checkKeys $m $strictKeys.Module "The module '$($m.Name)' in Uses.Modules"
                $install = if ($m.PSObject.Properties['Install'] -and $m.Install) { [string]$m.Install } else { 'Maester' }
                $process = if ($m.PSObject.Properties['Process'] -and $m.Process) { [string]$m.Process } else { 'Maester' }
                if ($install -notin 'Maester', 'User') { & $fail "The module '$($m.Name)' has Install '$install'; it must be Maester or User." }
                if ($process -notin 'Maester', 'Child') { & $fail "The module '$($m.Name)' has Process '$process'; it must be Maester or Child." }
                if ($install -eq 'User' -and $process -ne 'Child') {
                    & $fail "The module '$($m.Name)' is the user's own install (Install User), so it can only run in a child process (Process Child): a module Maester imports must be saved and pinned by Maester."
                }
                $exact = '^\d+(\.\d+){1,3}(-[0-9A-Za-z.-]+)?$'
                if ($install -eq 'Maester' -and [string]$m.Version -notmatch $exact) { & $fail "The module '$($m.Name)' must be pinned to one exact version, such as 1.4.2; it is '$($m.Version)'." }
                foreach ($k in 'Version', 'MinimumVersion') {
                    if ($install -eq 'User' -and $m.PSObject.Properties[$k] -and $m.$k -and [string]$m.$k -notmatch $exact) { & $fail "The $k of the module '$($m.Name)' must be a version such as 2.6.0; it is '$($m.$k)'." }
                }
                if ($install -eq 'Maester' -and $m.PSObject.Properties['MinimumVersion'] -and $m.MinimumVersion) { & $fail "The module '$($m.Name)' is saved by Maester, so it is pinned with Version, not MinimumVersion." }
            }
            foreach ($h in @(& $list 'Network' $uses.Value)) {
                if ($h -isnot [string] -or $h -notmatch '^(\*\.)?[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$') { & $fail "Uses.Network must list host names, such as 'admin.googleapis.com'; '$h' is not one." }
            }
        }
    }

    # Other packs this one needs (section 4.2).
    $requiresSection = $manifest.PSObject.Properties['Requires']
    if ($requiresSection -and $null -ne $requiresSection.Value) {
        & $checkKeys $requiresSection.Value $strictKeys.Requires 'Requires'
        foreach ($r in @(& $list 'Packs' $requiresSection.Value)) {
            & $checkKeys $r $strictKeys.RequiredPack 'Each entry of Requires.Packs'
            if (-not ($r.PSObject.Properties['Id'] -and $r.Id)) { & $fail 'Each entry of Requires.Packs needs the Id of the required pack.' }
        }
    }

    # Listing facts the pack index shows; Maester itself does not act on them.
    $pricing = & $text 'Pricing'
    if ($manifest.PSObject.Properties['Pricing'] -and $pricing -notin 'Free', 'Paid') { & $fail "Pricing must be Free or Paid; it is '$($manifest.Pricing)'." }
    if ($manifest.PSObject.Properties['Banner']) {
        $banner = & $text 'Banner'
        if (-not $banner -or -not (Test-MtPackRelativePath -Path $banner) -or $banner -notmatch '\.(png|jpe?g|webp)$') { & $fail 'Banner must be the path of a .png, .jpg or .webp image inside the pack.' }
    }

    foreach ($name in 'Listed', 'EnabledByDefault') {
        if ($manifest.PSObject.Properties[$name] -and $manifest.$name -isnot [bool]) { & $fail "$name must be true or false." }
    }

    # Every list present, so callers never test for missing keys.
    $normalised = [ordered]@{}
    foreach ($p in $manifest.PSObject.Properties) { $normalised[$p.Name] = $p.Value }
    $normalised['Suites'] = [string[]]@($folders.Suites | Where-Object { $_ -is [string] })
    $normalised['Helpers'] = [string[]]@($folders.Helpers | Where-Object { $_ -is [string] })
    $normalised['Connectors'] = @($connectors | Where-Object { $_ -is [pscustomobject] })
    $normalised['Exports'] = [string[]]@(& $list 'Exports')
    $usesValue = if ($uses -and $uses.Value -is [pscustomobject]) { $uses.Value } else { [pscustomobject]@{} }
    $normalised['Uses'] = [pscustomobject][ordered]@{
        Services     = [string[]]@(& $list 'Services' $usesValue)
        GraphScopes  = [string[]]@(& $list 'GraphScopes' $usesValue)
        TenantWrites = [string[]]@(& $list 'TenantWrites' $usesValue)
        Network      = [string[]]@(& $list 'Network' $usesValue)
        Modules      = @(& $list 'Modules' $usesValue | Where-Object { -not ($_.PSObject.Properties['Install'] -and $_.Install -eq 'User') })
        # Modules the user installs and the pack runs in a child process: never saved, pinned or imported by Maester.
        UserModules  = @(& $list 'Modules' $usesValue | Where-Object { $_.PSObject.Properties['Install'] -and $_.Install -eq 'User' })
    }
    $normalised['RequiredPacks'] = @($(if ($requiresSection -and $requiresSection.Value) { & $list 'Packs' $requiresSection.Value }))
    $normalised['Pricing'] = if ($pricing -eq 'Paid') { 'Paid' } else { 'Free' }
    $normalised['EnabledByDefault'] = if ($manifest.PSObject.Properties['EnabledByDefault'] -and $manifest.EnabledByDefault -is [bool]) { $manifest.EnabledByDefault } else { $true }
    if ($code) { $normalised['Code'] = $code }
    & $result ([pscustomobject]$normalised)
}

function Test-MtPackRelativePath {
    <#
    .SYNOPSIS
    True when a path from a manifest is relative and stays inside the pack.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ([System.IO.Path]::IsPathRooted($Path) -or $Path -match '^[A-Za-z]:' -or $Path.StartsWith('/') -or $Path.StartsWith('\')) { return $false }
    -not (@($Path -split '[\\/]') -contains '..')
}

function Test-MtPackReservedName {
    <#
    .SYNOPSIS
    Returns why a pack code or a connector service name is reserved (Maester Packs design, section 4.6), or $null.

    .DESCRIPTION
    Codes: the first part of a code may not be a built-in suite name, a name that looks official, a product
    acronym or a well-known brand. It is reserved when it equals an entry, or an entry followed by one digit.
    The index keeps the full list (Simple Icons and the S&P 500 tickers); this snapshot only keeps publishers
    away from the obvious ones before it exists.

    Service names: a community connector's service is '<Code>.<Name>', 3 to 40 letters and digits after the
    code. Bare platform names are for official connectors, and Maester's own names are never available.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowEmptyString()] [AllowNull()] [string] $Code,
        [Parameter()] [string] $Service,
        [Parameter()] [switch] $Official
    )

    $builtInSuites = @('MT', 'CIS', 'CISA', 'AD', 'AZDO', 'ORCA', 'EIDSCA', 'XSPM', 'MP')
    $officialNames = @('MS', 'MSFT', 'MAESTER', 'MAES', 'M365', 'O365', 'AAD', 'GWS', 'ENTRA', 'AZURE', 'INTUNE', 'TEAMS', 'OFFICE', 'WIN', 'WINDOWS')
    $brands = @('GOOG', 'GOOGL', 'GCP', 'AMZN', 'AWS', 'META', 'FB', 'APPLE', 'AAPL', 'OKTA', 'ZOOM', 'SLACK', 'CISCO', 'CSCO', 'BOX', 'CRM',
        'SFDC', 'PANW', 'CRWD', 'ZS', 'FTNT', 'NET', 'DDOG', 'SNOW', 'ADBE', 'ORCL', 'IBM', 'VMW', 'ATLASSIAN', 'TEAM', 'GH', 'GITHUB',
        'GITLAB', 'DOCU', 'DBX', 'WDAY', 'NOW', 'TWLO', 'AKAM', 'CHKP', 'JAMF', 'SAP')

    if ($Service) {
        if ($Service -notmatch '^(?:[A-Za-z][A-Za-z0-9]{1,9}\.){0,3}[A-Za-z][A-Za-z0-9]{2,39}$') {
            return "The service name '$Service' must be '<code>.<Name>', with 3 to 40 letters and digits after the code, for example 'CNT.GoogleWorkspace'."
        }
        $registry = Get-MtServiceRegistry -BuiltInOnly
        $ownNames = @('All', 'None', 'EOP', 'Pack', 'Packs', 'Telemetry', 'Maester') + @($registry.Services.Keys) + @($registry.Services.Values | ForEach-Object { $_.Aliases } | Where-Object { $_ })
        $name = $Service.Split('.')[-1]
        if ($ownNames | Where-Object { $_ -eq $Service -or $_ -eq $name }) { return "The service name '$Service' is reserved by Maester." }
        if (-not $Service.Contains('.')) {
            if (-not $Official) { return "The service name '$Service' is a bare platform name, which is reserved for official connectors. Use '<code>.$Service' with your pack's code." }
        } elseif ($Code -and $Service.Substring(0, $Service.LastIndexOf('.')) -ne $Code) {
            return "The service name '$Service' must start with the pack's code: '$Code.$name'."
        }
        return $null
    }

    if (-not $Code) { return $null }
    $value = $Code.Split('.')[0].ToUpperInvariant()
    $stem = if ($value -match '^(.*[A-Z])\d$') { $Matches[1] } else { $value }
    if ($Official -and $value -eq 'MAES') { return $null }
    foreach ($entry in ($builtInSuites + $officialNames + $brands)) {
        if ($value -eq $entry -or $stem -eq $entry) {
            $why = if ($entry -in $builtInSuites) { 'a built-in suite' } elseif ($entry -eq 'MAES') { 'the maester365 organisation' } elseif ($entry -in $officialNames) { 'names that look official' } else { 'a well-known brand' }
            $what = if ($Code.Contains('.')) { "The code '$($Code.ToUpperInvariant())' starts with '$value', which" } else { "The code '$value'" }
            return "$what is reserved for $why. Pick another code for your pack."
        }
    }
    $null
}

function Test-MtVersionRange {
    <#
    .SYNOPSIS
    Checks a version against a range such as '>=3.1 <4.0', '3.1', '^1.2' or '~1.2.3'.

    .DESCRIPTION
    A range is one or more comparisons separated by spaces, all of which must hold: >=, >, <=, < or =
    followed by a version. A bare version means at least that version. ^1.2 means >=1.2 <2.0 and ~1.2.3
    means >=1.2.3 <1.3. With -Validate only the range is checked, and the result says whether it parses.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Range,
        [Parameter()] [AllowNull()] [object] $Version,
        [Parameter()] [switch] $Validate
    )

    $toVersion = {
        param($text)
        $core = ($text -split '-', 2)[0]
        $parts = @($core.Split('.') | ForEach-Object { $_ })
        while ($parts.Count -lt 3) { $parts += '0' }
        $parsed = $null
        if ([version]::TryParse(($parts[0..2] -join '.'), [ref] $parsed)) { $parsed } else { $null }
    }
    $clauses = [System.Collections.Generic.List[object]]::new()
    foreach ($token in ($Range.Trim() -split '\s+' | Where-Object { $_ })) {
        if ($token -notmatch '^(>=|<=|>|<|=|\^|~)?v?(\d+(\.\d+){0,2}(-[0-9A-Za-z.-]+)?)$') { return $false }
        $op = if ($Matches[1]) { $Matches[1] } else { '>=' }
        $v = & $toVersion $Matches[2]
        if (-not $v) { return $false }
        switch ($op) {
            '^' { $clauses.Add(@('>=', $v)); $clauses.Add(@('<', [version]::new($v.Major + 1, 0, 0))) }
            '~' { $clauses.Add(@('>=', $v)); $clauses.Add(@('<', [version]::new($v.Major, $v.Minor + 1, 0))) }
            default { $clauses.Add(@($op, $v)) }
        }
    }
    if ($clauses.Count -eq 0) { return $false }
    if ($Validate) { return $true }

    $actual = if ($Version -is [version]) { [version]::new($Version.Major, [math]::Max($Version.Minor, 0), [math]::Max($Version.Build, 0)) } else { & $toVersion ([string]$Version) }
    if (-not $actual) { return $false }
    foreach ($c in $clauses) {
        $ok = switch ($c[0]) {
            '>=' { $actual -ge $c[1] } '>' { $actual -gt $c[1] } '<=' { $actual -le $c[1] } '<' { $actual -lt $c[1] } '=' { $actual -eq $c[1] }
        }
        if (-not $ok) { return $false }
    }
    $true
}

function Test-MtPackCodeOverlap {
    <#
    .SYNOPSIS
    True when two pack codes would give tests with the same ID prefix: the codes are equal, or one is the other
    followed by more parts (CNT and CNT.GWS), so MP.CNT.GWS.1001 could belong to either pack.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Code,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Other
    )

    if (-not $Code -or -not $Other) { return $false }
    $a = $Code.ToUpperInvariant(); $b = $Other.ToUpperInvariant()
    $a -eq $b -or $a.StartsWith("$b.") -or $b.StartsWith("$a.")
}

function Test-MtPackTestId {
    <#
    .SYNOPSIS
    True when a test ID belongs to a pack with this code: MP.<Code> itself (a family, whose instances add a
    part) or MP.<Code>.<anything>. A pack that ships with Maester is part of Maester, so its IDs drop the MP
    prefix: <Code> or <Code>.<anything>, such as ZTA.21770.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Id,
        [Parameter(Mandatory)] [string] $Code,
        # The pack ships with Maester.
        [Parameter()] [switch] $BuiltIn
    )

    $prefix = if ($BuiltIn) { $Code } else { "MP.$Code" }
    $Id.Equals($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or $Id.StartsWith("$prefix.", [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-MtPackTestIdPrefix {
    <#
    .SYNOPSIS
    The prefix of a pack's test IDs: MP.<Code>, or <Code> for a pack that ships with Maester.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Code,
        [Parameter()] [switch] $BuiltIn
    )

    if ($BuiltIn) { $Code } else { "MP.$Code" }
}
