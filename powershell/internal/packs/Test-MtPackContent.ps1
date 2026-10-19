function Test-MtPackContent {
    <#
    .SYNOPSIS
    Validates a pack folder and scans it locally, without running any of it (Maester Packs design, sections 4.3 and 9.6).

    .DESCRIPTION
    Reads the manifest, every file and the AST of every PowerShell file, and returns:

    - Errors: what stops the pack from being installed or loaded. The manifest rules; no symbolic links,
      no paths that differ only in case, at most 50 MB per pack and 20 MB per file; PowerShell files that
      hold only function definitions; function names unique within the pack (DuplicateFunctionName); test
      IDs 'MP.<Code>.<number>' and suite IDs that start with the code; no reserved tags; services that are
      built in, declared by the pack's connectors or listed in Uses.Services; and reach that the code shows
      but Uses does not declare (a literal web host, a module it imports, a tenant write).
    - Findings: what a person should read before installing (Severity Medium or High, Code, Message, File, Line).
    - Risk: Low (text only and nothing to read), Medium (findings, or Gallery modules), or High (compiled or
      encoded content, archives, tenant writes, write scopes, or modules from outside the store).
    - Binaries: every file whose bytes are not text, with its size and SHA-256.
    - Tests: the pack's tests as the engine reads them, and TestIds.
    - Digest and Files: as Get-MtPackDigest returns them.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The pack folder (holding maester-pack.json).
        [Parameter(Mandatory)]
        [string] $Path,

        # The pack is published by maester365.
        [Parameter()]
        [switch] $Official,

        # Services that packs this one requires provide (their connectors' service names).
        [Parameter()]
        [string[]] $RequiredService = @()
    )

    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $read = Read-MtPackManifest -Path $root -Official:$Official
    $errors = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($e in $read.Errors) { $errors.Add($e) }
    $warnings = [System.Collections.Generic.List[string]]::new()
    foreach ($w in $read.Warnings) { $warnings.Add($w) }
    $findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $binaries = [System.Collections.Generic.List[pscustomobject]]::new()
    $fail = { param($code, $message) $errors.Add([pscustomobject]@{ Code = $code; Message = $message }) }
    $find = { param($severity, $code, $message, $file, $line) $findings.Add([pscustomobject]@{ Severity = $severity; Code = $code; Message = $message; File = $file; Line = $line }) }
    $manifest = $read.Manifest

    # Files: links, case, size, and what is not text.
    $all = @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' })
    foreach ($link in ($all | Where-Object { $_.LinkType -or ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) })) {
        & $fail 'SymbolicLink' "The pack contains a symbolic link: $([System.IO.Path]::GetRelativePath($root, $link.FullName))."
    }
    $digest = Get-MtPackDigest -Path $root
    foreach ($group in ($digest.Files | Group-Object { $_.Path.ToLowerInvariant() } | Where-Object Count -GT 1)) {
        & $fail 'CaseCollision' "These paths differ only in case: $($group.Group.Path -join ', ')."
    }
    $total = ($digest.Files | Measure-Object -Property Size -Sum).Sum
    if ($total -gt 50MB) { & $fail 'TooLarge' "The pack is $([math]::Round($total / 1MB, 1)) MB; at most 50 MB is allowed." }
    $archive = @('.zip', '.nupkg', '.7z', '.tar', '.gz', '.tgz', '.rar', '.cab', '.msi', '.jar', '.whl')
    $compiled = @('.dll', '.exe', '.so', '.dylib', '.pyc', '.pyo', '.wasm', '.class', '.node')
    foreach ($f in $digest.Files) {
        if ($f.Size -gt 20MB) { & $fail 'TooLarge' "$($f.Path) is $([math]::Round($f.Size / 1MB, 1)) MB; at most 20 MB is allowed per file." }
        $full = Join-Path $root $f.Path
        $extension = [System.IO.Path]::GetExtension($f.Path).ToLowerInvariant()
        if ($extension -in $archive -or $extension -in $compiled -or (Test-MtPackBinaryFile -Path $full)) {
            $kind = if ($extension -in $archive) { 'archive' } elseif ($extension -in $compiled) { 'compiled code' } else { 'binary content' }
            $signer = $null
            if ($IsWindows -and $extension -in '.dll', '.exe') {
                try { $signature = Get-AuthenticodeSignature -LiteralPath $full -ErrorAction Stop; if ($signature.SignerCertificate) { $signer = $signature.SignerCertificate.GetNameInfo('SimpleName', $false) } } catch { Write-Debug $_ }
            }
            $binaries.Add([pscustomobject]@{ Path = $f.Path; Size = $f.Size; Sha256 = $f.Sha256; Kind = $kind; Signer = $signer })
            & $find 'High' 'Unscannable' "$($f.Path) is $kind that could not be scanned." $f.Path $null
            continue
        }
        if ($extension -in '.ps1', '.psm1', '.psd1', '.json', '.md', '.txt', '.yml', '.yaml', '.xml') {
            $text = [System.IO.File]::ReadAllText($full)
            if ([regex]::IsMatch($text, '[A-Za-z0-9+/]{4096,}={0,2}')) { & $find 'High' 'EncodedContent' "$($f.Path) holds a long encoded block that could not be scanned." $f.Path $null }
        }
    }

    if (-not $manifest) {
        return [pscustomobject]@{ Manifest = $null; Errors = $errors.ToArray(); Warnings = $warnings.ToArray(); Findings = $findings.ToArray(); Risk = 'High'; Binaries = $binaries.ToArray(); Tests = @(); TestIds = @(); Digest = $digest.Digest; Files = $digest.Files }
    }

    # The folders and files the manifest names.
    foreach ($folder in @($manifest.Suites) + @($manifest.Helpers)) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $folder) -PathType Container)) { & $fail 'InvalidManifest' "The folder '$folder' named in maester-pack.json does not exist." }
    }
    foreach ($c in $manifest.Connectors) {
        if ($c.File -and -not (Test-Path -LiteralPath (Join-Path $root $c.File) -PathType Leaf)) { & $fail 'InvalidManifest' "The connector file '$($c.File)' does not exist." }
    }

    # Every PowerShell file: function definitions only; names unique; then the scan.
    $functionFiles = @{}
    $declaredHosts = @($manifest.Uses.Network)
    $declaredModules = @(@($manifest.Uses.Modules) + @($manifest.Uses.UserModules) | ForEach-Object { [string]$_.Name })
    $declaredWrites = @($manifest.Uses.TenantWrites).Count -gt 0
    foreach ($f in ($digest.Files | Where-Object { $_.Path -match '\.ps(m?)1$' })) {
        $scan = Test-MtPackScriptFile -Path (Join-Path $root $f.Path) -DeclaredHost $declaredHosts -DeclaredModule $declaredModules -DeclaredWrites:$declaredWrites
        foreach ($e in $scan.Errors) { & $fail $e.Code "$($f.Path), line $($e.Line): $($e.Message)" }
        foreach ($finding in $scan.Findings) { & $find $finding.Severity $finding.Code $finding.Message $f.Path $finding.Line }
        foreach ($name in $scan.Functions) {
            $key = $name.ToLowerInvariant()
            if ($functionFiles.ContainsKey($key)) { & $fail 'DuplicateFunctionName' "The function $name is defined in both $($functionFiles[$key]) and $($f.Path). Function names must be unique within a pack." }
            else { $functionFiles[$key] = $f.Path }
        }
    }
    foreach ($c in $manifest.Connectors) {
        foreach ($fn in 'Connect', 'Test', 'Disconnect', 'Describe', 'Renew') {
            if ($c.PSObject.Properties[$fn] -and $c.$fn -and -not $functionFiles.ContainsKey(([string]$c.$fn).ToLowerInvariant())) {
                & $fail 'InvalidManifest' "The connector '$($c.Service)' names the function $($c.$fn), which the pack does not define."
            }
        }
    }
    foreach ($name in $manifest.Exports) {
        if (-not $functionFiles.ContainsKey($name.ToLowerInvariant())) { & $fail 'InvalidManifest' "Exports names the function $name, which the pack does not define." }
    }

    # Tests: the 3.0 rules, plus the pack rules.
    $tests = @()
    $packServices = @($manifest.Connectors | ForEach-Object { [string]$_.Service }) + @($RequiredService) + @($manifest.Uses.Services)
    $reservedTags = Get-MtPackReservedTag
    foreach ($folder in $manifest.Suites) {
        $suiteRoot = Join-Path $root $folder
        if (-not (Test-Path -LiteralPath $suiteRoot -PathType Container)) { continue }
        $suiteTests = @(Get-MtNativeTestInventory -Path $suiteRoot -Root $suiteRoot -WarningAction SilentlyContinue)
        foreach ($suiteFile in (Get-ChildItem -LiteralPath $suiteRoot -Recurse -File -Filter 'suite.json' -ErrorAction SilentlyContinue)) {
            try { $suite = Get-Content -LiteralPath $suiteFile.FullName -Raw | ConvertFrom-Json -ErrorAction Stop } catch { & $fail 'InvalidManifest' "$([System.IO.Path]::GetRelativePath($root, $suiteFile.FullName)) is not valid JSON."; continue }
            $relative = [System.IO.Path]::GetRelativePath($root, $suiteFile.FullName)
            if ($manifest.Code -and -not ($suite.PSObject.Properties['Id'] -and ([string]$suite.Id -eq $manifest.Code -or ([string]$suite.Id).StartsWith("$($manifest.Code).", [System.StringComparison]::OrdinalIgnoreCase)))) {
                & $fail 'InvalidSuite' "$relative has the Id '$($suite.Id)'; a suite in a pack must have the pack's code as its Id or start with it, such as '$($manifest.Code)' or '$($manifest.Code).Admin'."
            }
            foreach ($tag in @($(if ($suite.PSObject.Properties['Tags']) { $suite.Tags }))) {
                if ($reservedTags -contains [string]$tag) { & $fail 'ReservedTag' "$relative sets the tag '$tag', which is reserved for the checks that ship with Maester." }
            }
        }
        foreach ($t in $suiteTests) {
            $file = [System.IO.Path]::GetRelativePath($root, $t.File)
            foreach ($e in $t.Errors) { & $fail $e.Code "$file, line $($e.Line): $($e.Message)" }
            if ($t.Id -and $manifest.Code -and -not $t.Id.StartsWith("MP.$($manifest.Code).", [System.StringComparison]::OrdinalIgnoreCase)) {
                & $fail 'InvalidTestId' "$file has the ID $($t.Id); every test in this pack must have an ID that starts with MP.$($manifest.Code)., such as MP.$($manifest.Code).0001."
            }
            foreach ($tag in @($t.Tag)) {
                if ($reservedTags -contains [string]$tag) { & $fail 'ReservedTag' "$file sets the tag '$tag', which is reserved for the checks that ship with Maester." }
            }
            foreach ($s in @($t.UnregisteredServices)) {
                if (-not ($packServices | Where-Object { $_ -eq $s })) { & $fail 'UnknownService' "$file lists the service '$s', which is neither built in nor provided by a connector of this pack or a pack it requires." }
            }
        }
        $tests += $suiteTests
    }
    foreach ($group in ($tests | Where-Object Id | Group-Object { $_.Id.ToLowerInvariant() } | Where-Object Count -GT 1)) {
        & $fail 'DuplicateId' "The ID $($group.Group[0].Id) is used by more than one test: $(($group.Group | ForEach-Object { [System.IO.Path]::GetRelativePath($root, $_.File) }) -join ', ')."
    }

    # What the manifest says the pack reaches.
    if (@($manifest.Uses.Modules).Count -gt 0) {
        & $find 'Medium' 'Dependencies' "The pack uses $(@($manifest.Uses.Modules).Count) PowerShell Gallery module(s): $(($manifest.Uses.Modules | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ')." $null $null
    }
    if (@($manifest.Uses.UserModules).Count -gt 0) {
        $named = ($manifest.Uses.UserModules | ForEach-Object { $v = if ($_.PSObject.Properties['Version'] -and $_.Version) { " $($_.Version)" } elseif ($_.PSObject.Properties['MinimumVersion'] -and $_.MinimumVersion) { " $($_.MinimumVersion) or newer" } else { '' }; "$($_.Name)$v" }) -join ', '
        # Externally managed code: the lock cannot pin it, so the risk and the policy say so (Sam Erde's review of the design).
        & $find 'High' 'UserModules' "The pack runs your own install of $named in a separate PowerShell process. Maester does not save, pin or check those files, so a change to them needs no new approval." $null $null
    }
    $writeScopes = @($manifest.Uses.GraphScopes | Where-Object { $_ -match 'ReadWrite|\.Write(\.|$)|\.Manage[A-Za-z]*(\.|$)|FullControl|\.Send(\.|$)' })
    if ($writeScopes) { & $find 'High' 'WriteScope' "The pack asks for Microsoft Graph scopes that can change your tenant: $($writeScopes -join ', ')." $null $null }
    if ($declaredWrites) { & $find 'High' 'TenantWrite' "The pack declares changes it can make to your tenant: $(@($manifest.Uses.TenantWrites) -join ', ')." $null $null }

    $risk = if ($findings | Where-Object Severity -EQ 'High') { 'High' } elseif ($findings.Count -gt 0) { 'Medium' } else { 'Low' }
    [pscustomobject]@{
        Manifest = $manifest
        Errors   = $errors.ToArray()
        Warnings = $warnings.ToArray()
        Findings = $findings.ToArray()
        Risk     = $risk
        Binaries = $binaries.ToArray()
        Tests    = $tests
        TestIds  = [string[]]@($tests | Where-Object Id | ForEach-Object { $_.Id } | Sort-Object -Unique)
        Digest   = $digest.Digest
        Files    = $digest.Files
    }
}

function Test-MtPackBinaryFile {
    <#
    .SYNOPSIS
    True when a file's first 8000 bytes hold a NUL byte, which text files do not (the way Git tells binaries apart).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string] $Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = [byte[]]::new(8000)
        $read = $stream.Read($buffer, 0, $buffer.Length)
        # UTF-16 text has NUL bytes too; its byte order mark says so.
        if ($read -ge 2 -and (($buffer[0] -eq 0xFF -and $buffer[1] -eq 0xFE) -or ($buffer[0] -eq 0xFE -and $buffer[1] -eq 0xFF))) { return $false }
        for ($i = 0; $i -lt $read; $i++) { if ($buffer[$i] -eq 0) { return $true } }
        $false
    } finally { $stream.Dispose() }
}

function Get-MtPackReservedTag {
    <#
    .SYNOPSIS
    Returns the tags a pack cannot set: the built-in suite and source names (Maester Packs design, section 4.4).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    [string[]]@('Maester', 'MT', 'CIS', 'CISA', 'EIDSCA', 'ORCA', 'AD', 'AZDO', 'XSPM', 'All', 'Custom')
}

function Test-MtPackScriptFile {
    <#
    .SYNOPSIS
    Checks one PowerShell file of a pack: function definitions only, then scans it for what it reaches.

    .DESCRIPTION
    Returns Functions (the names defined at the top level), Errors (Code, Message, Line) and Findings
    (Severity, Code, Message, Line).

    A file must not run code when it is loaded (section 4.3): no top-level statements, no script param
    block, no using statements, no class or enum definitions and no #Requires -Modules other than Maester.

    The scan reads the AST (section 9.6): dynamic code (Invoke-Expression, [scriptblock]::Create,
    Add-Type), process start and web requests to an address built at run time are Medium findings. A web
    request to a literal host that Uses.Network does not list, a module import or install that Uses.Modules
    does not list, and a write through Invoke-MtGraphRequest or Invoke-MtAzureRequest when Uses.TenantWrites
    is empty are errors: undeclared reach.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter()] [string[]] $DeclaredHost = @(),
        [Parameter()] [string[]] $DeclaredModule = @(),
        [Parameter()] [switch] $DeclaredWrites
    )

    $errors = [System.Collections.Generic.List[pscustomobject]]::new()
    $findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $fail = { param($code, $message, $line) $errors.Add([pscustomobject]@{ Code = $code; Message = $message; Line = $line }) }
    $find = { param($severity, $code, $message, $line) $findings.Add([pscustomobject]@{ Severity = $severity; Code = $code; Message = $message; Line = $line }) }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $parseErrors)
    if ($parseErrors) {
        foreach ($e in ($parseErrors | Select-Object -First 3)) { & $fail 'LoadFailed' "The file does not parse: $($e.Message)" $e.Extent.StartLineNumber }
        return [pscustomobject]@{ Functions = @(); Errors = $errors.ToArray(); Findings = $findings.ToArray() }
    }

    # Nothing may run when the file is loaded.
    if ($ast.ParamBlock) { & $fail 'CodeOnLoad' 'A pack file must not have a script-level param() block.' $ast.ParamBlock.Extent.StartLineNumber }
    foreach ($using in $ast.UsingStatements) { & $fail 'CodeOnLoad' "A pack file must not use '$($using.Extent.Text)': it runs when the file is loaded. Load libraries inside a function instead." $using.Extent.StartLineNumber }
    foreach ($block in @($ast.BeginBlock, $ast.ProcessBlock, $ast.DynamicParamBlock)) {
        if ($block -and $block.Statements.Count -gt 0) { & $fail 'CodeOnLoad' 'A pack file may contain only function definitions at the top level.' $block.Extent.StartLineNumber }
    }
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [System.Management.Automation.Language.TypeDefinitionAst]) { & $fail 'CodeOnLoad' "A pack file must not define the class or enum '$($statement.Name)': it is compiled when the file is loaded." $statement.Extent.StartLineNumber }
        elseif ($statement -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { & $fail 'CodeOnLoad' "A pack file may contain only function definitions at the top level; found '$($statement.Extent.Text.Split("`n")[0].Trim())'." $statement.Extent.StartLineNumber }
    }
    if ($ast.ScriptRequirements) {
        foreach ($m in $ast.ScriptRequirements.RequiredModules) {
            if ($m.Name -ne 'Maester') { & $fail 'CodeOnLoad' "A pack file must not use '#Requires -Modules $($m.Name)': it loads the module when the file is loaded. Declare it in Uses.Modules." 1 }
        }
        foreach ($a in $ast.ScriptRequirements.RequiredAssemblies) { & $fail 'CodeOnLoad' "A pack file must not use '#Requires -Assembly $a'." 1 }
    }
    $functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object { $_.Name })

    # The scan.
    $microsoftModules = '^(Microsoft\.Graph(\..+)?|Az(\..+)?|ExchangeOnlineManagement|MicrosoftTeams|PnP\.PowerShell|Microsoft\.Online\.SharePoint\.PowerShell|Maester|Pester|Microsoft\.PowerShell\..+)$'
    $hostAllowed = {
        param($name, $hosts)
        foreach ($h in $hosts) {
            if ($h.StartsWith('*.')) { if ($name.EndsWith($h.Substring(1), [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
            elseif ($h -eq $name) { return $true }
        }
        $false
    }
    $commands = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($command in $commands) {
        $name = $command.GetCommandName()
        if (-not $name) { & $find 'Medium' 'DynamicCode' 'Calls a command whose name is computed at run time.' $command.Extent.StartLineNumber; continue }
        $line = $command.Extent.StartLineNumber
        $arguments = Get-MtPackCommandArgument -Command $command
        switch -Regex ($name) {
            '^(Invoke-Expression|iex)$' { & $find 'Medium' 'DynamicCode' 'Runs a string as code (Invoke-Expression).' $line }
            '^Add-Type$' { & $find 'Medium' 'DynamicCode' 'Compiles or loads code at run time (Add-Type).' $line }
            '^(Start-Process|saps|start)$' { & $find 'Medium' 'ProcessStart' 'Starts another process (Start-Process).' $line }
            '^(Invoke-RestMethod|irm|Invoke-WebRequest|iwr|curl|wget)$' {
                $uri = if ($arguments.Named.ContainsKey('Uri')) { $arguments.Named['Uri'] } elseif ($arguments.Positional.Count -gt 0) { $arguments.Positional[0] } else { $null }
                $literal = Get-MtPackLiteralString -Ast $uri
                if ($literal -and $literal -match '^https?://([^/:?#]+)') {
                    if (-not (& $hostAllowed $Matches[1] $DeclaredHost)) { & $fail 'UndeclaredNetwork' "Sends a web request to $($Matches[1]), which Uses.Network does not list." $line }
                } else { & $find 'Medium' 'DynamicUrl' 'Sends a web request to an address built at run time.' $line }
            }
            '^(Import-Module|ipmo|Install-Module|Install-PSResource|Save-Module|Save-PSResource|Install-Package)$' {
                $target = if ($arguments.Named.ContainsKey('Name')) { $arguments.Named['Name'] } elseif ($arguments.Positional.Count -gt 0) { $arguments.Positional[0] } else { $null }
                $module = Get-MtPackLiteralString -Ast $target
                if ($name -notmatch '^(Import-Module|ipmo)$') { & $fail 'UndeclaredModule' "Installs a module at run time ($name). Declare modules in Uses.Modules; Maester saves and checks them at install." $line }
                elseif (-not $module) { & $find 'Medium' 'DynamicCode' 'Imports a module whose name is computed at run time.' $line }
                elseif ($module -notmatch $microsoftModules -and -not ($DeclaredModule | Where-Object { $_ -eq $module }) -and $module -notmatch '[\\/]') {
                    & $fail 'UndeclaredModule' "Imports the module $module, which Uses.Modules does not list." $line
                }
            }
            '^(Invoke-MtGraphRequest|Invoke-MgGraphRequest|Invoke-MtAzureRequest|Invoke-AzRestMethod)$' {
                $method = Get-MtPackLiteralString -Ast $(if ($arguments.Named.ContainsKey('Method')) { $arguments.Named['Method'] } else { $null })
                if ($method -and $method -match '^(POST|PATCH|PUT|DELETE)$' -and -not $DeclaredWrites) {
                    & $fail 'UndeclaredTenantWrite' "Sends a $($method.ToUpperInvariant()) request through $name, a change to your tenant that Uses.TenantWrites does not declare." $line
                }
            }
        }
    }
    foreach ($member in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)) {
        $target = $member.Expression.Extent.Text
        $method = $member.Member.Extent.Text.Trim("'", '"')
        if ($target -match '^\[(System\.Management\.Automation\.)?scriptblock\]$' -and $method -eq 'Create') { & $find 'Medium' 'DynamicCode' 'Creates code from a string ([scriptblock]::Create).' $member.Extent.StartLineNumber }
        elseif ($target -match '^\[(System\.)?Diagnostics\.Process\]$' -and $method -eq 'Start') { & $find 'Medium' 'ProcessStart' 'Starts another process ([Diagnostics.Process]::Start).' $member.Extent.StartLineNumber }
        elseif ($target -match '^\[(System\.)?Reflection\.Assembly\]$' -and $method -match '^Load') { & $find 'Medium' 'DynamicCode' 'Loads an assembly at run time.' $member.Extent.StartLineNumber }
    }

    [pscustomobject]@{ Functions = [string[]]$functions; Errors = $errors.ToArray(); Findings = $findings.ToArray() }
}

function Get-MtPackCommandArgument {
    <#
    .SYNOPSIS
    Splits a command's arguments from its AST into named (by parameter name, the value's AST) and positional ones.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [System.Management.Automation.Language.CommandAst] $Command)

    $named = @{}
    $positional = [System.Collections.Generic.List[object]]::new()
    $elements = $Command.CommandElements
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $element = $elements[$i]
        if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
            $value = $element.Argument
            if (-not $value -and $i + 1 -lt $elements.Count -and $elements[$i + 1] -isnot [System.Management.Automation.Language.CommandParameterAst]) { $value = $elements[$i + 1]; $i++ }
            # Abbreviations are matched by the start of the name, as PowerShell does.
            $key = switch -Regex ($element.ParameterName) { '^u' { 'Uri' } '^me' { 'Method' } '^n' { 'Name' } default { $element.ParameterName } }
            $named[$key] = $value
        } else { $positional.Add($element) }
    }
    [pscustomobject]@{ Named = $named; Positional = $positional }
}

function Get-MtPackLiteralString {
    <#
    .SYNOPSIS
    Returns the text of a constant string argument, or $null when the value is built at run time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter()] [AllowNull()] [object] $Ast)

    if ($Ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $Ast.Value }
    if ($Ast -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        # "https://host/$path" still names its host before the first variable.
        if ($Ast.Value -match '^(https?://[^/$]+)/') { return $Matches[1] + '/' }
        if ($Ast.NestedExpressions.Count -eq 0) { return $Ast.Value }
    }
    $null
}
