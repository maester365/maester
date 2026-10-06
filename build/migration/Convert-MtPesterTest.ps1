<#
.SYNOPSIS
    Converts built-in Maester checks from the 2.x Pester format to native tests (Maester 3.0 design, section 14).

.DESCRIPTION
    For each check ID, reads the wrapper It, the check function, the golden tag file, the shipped
    maester-config.json row and the authorship seed, then:

    - writes the [MaesterTest(...)] attribute (Id, Title, Severity, Category, Tag, Preview, LongRunning,
      Service, CompatibleLicense, Author, Contributor, HelpUrl);
    - removes the canonical connection and licence guards at the top of the function and the outer
      try/catch whose catch only reports -SkippedBecause Error (both are done by the engine);
    - moves the function file and its .md to tests/<suite>/<area>/Test.<ID>.ps1 and .md (Move mode), or,
      when the wrapper passes arguments, inverts the result or shares the function with other IDs,
      moves the function to powershell/internal/checks and writes a thin Test.<ID>.ps1 that calls it
      (Thin mode);
    - removes the wrapper It (and the wrapper file when it becomes empty) and the config row.

    Anything else is left untouched and listed in the report for a person to convert. The converter
    never runs test code: it works from the AST.

.PARAMETER Id
    The check IDs to convert.

.PARAMETER Suite
    Converts every check whose wrapper is in tests/<Suite> (for example cis, cisa, ad, Maester, XSPM).

.PARAMETER ReportPath
    Where to write the JSON report. Defaults to build/migration/reports/<timestamp>.json.

.PARAMETER WhatIf
    Writes the report without changing any file.

.EXAMPLE
    ./build/migration/Convert-MtPesterTest.ps1 -Id MT.1001, MT.1005

.EXAMPLE
    ./build/migration/Convert-MtPesterTest.ps1 -Suite cis -WhatIf
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Build tool console output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Script supports -WhatIf through a switch')]
[CmdletBinding()]
param (
    [Parameter()] [string[]] $Id,
    [Parameter()] [string] $Suite,
    [Parameter()] [string] $ReportPath,
    [Parameter()] [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
# pwsh -File passes a comma-separated list as one string.
if ($Id) { $Id = @($Id | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$TestsRoot = Join-Path $RepoRoot 'tests'
$PowerShellRoot = Join-Path $RepoRoot 'powershell'
$Golden = (Get-Content (Join-Path $RepoRoot 'powershell/tests/fixtures/golden/tags-and-blocks.json') -Raw | ConvertFrom-Json).Entries
$Seed = @{}
foreach ($row in (Import-Csv (Join-Path $RepoRoot 'docs/proposals/maester-3.0-evidence/authorship-seed.csv'))) { $Seed[$row.test_id] = $row }
$ConfigPath = Join-Path $TestsRoot 'maester-config.json'

# ---------------------------------------------------------------------------------------------- helpers

function Get-Ast {
    param([string] $Path)
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors) { throw "Parse error in ${Path}: $($errors[0].Message)" }
    [pscustomobject]@{ Ast = $ast; Tokens = $tokens; Text = [System.IO.File]::ReadAllText($Path) }
}

function Get-SuiteFolder {
    param([string] $WrapperFile)
    ($WrapperFile -replace '\\', '/').Split('/')[1]
}

function Get-SuiteTag {
    param([string] $Folder)
    $manifest = Join-Path $TestsRoot "$Folder/suite.json"
    if (Test-Path $manifest) { @((Get-Content $manifest -Raw | ConvertFrom-Json).Tags) } else { @() }
}

function Get-ItTitle {
    # The 2.x result Title: the name without the 'See https' suffix, after the first colon.
    param([string] $Name)
    $url = $null
    $start = $Name.IndexOf('See https')
    if ($start -gt 0) { $url = $Name.Substring($start + 4).Trim(); $Name = $Name.Substring(0, $start).Trim() }
    $colon = $Name.IndexOf(':')
    $title = if ($colon -gt 0) { $Name.Substring($colon + 1).Trim() } else { $Name }
    [pscustomobject]@{ Title = $title; Url = $url }
}

$ConnectionServices = @{
    'Graph' = 'Graph'; 'ExchangeOnline' = 'ExchangeOnline'; 'SecurityCompliance' = 'SecurityCompliance'; 'EOP' = 'SecurityCompliance'
    'Teams' = 'Teams'; 'Azure' = 'Azure'; 'SharePointOnline' = 'SharePointOnline'; 'AzureDevOps' = 'AzureDevOps'; 'GitHub' = 'GitHub'
    'ActiveDirectory' = 'ActiveDirectory'
}

function Test-SkipBody {
    # True when a statement block only reports a skip (and optionally writes verbose output) and returns.
    param([System.Management.Automation.Language.StatementBlockAst] $Block, [string[]] $Codes)
    $statements = @($Block.Statements)
    if ($statements.Count -lt 1 -or $statements.Count -gt 3) { return $false }
    $hasSkip = $false
    foreach ($s in $statements) {
        $text = $s.Extent.Text.Trim()
        if ($text -match '^Add-MtTestResultDetail\s+-SkippedBecause\s+([A-Za-z0-9]+)\s*$') {
            if ($Codes -and $Matches[1] -notin $Codes) { return $false }
            $hasSkip = $true; continue
        }
        if ($text -match '^return(\s+\$null)?$') { continue }
        if ($text -match '^Write-Verbose\b') { continue }
        return $false
    }
    $hasSkip
}

function Get-GuardInfo {
    # Recognises the canonical guards at the top of a function body. Returns the guard statements and
    # what they declare (services and licence tokens).
    param([System.Management.Automation.Language.NamedBlockAst] $Body)
    $guards = [System.Collections.Generic.List[object]]::new()
    $services = [System.Collections.Generic.List[string]]::new()
    $licenses = [System.Collections.Generic.List[string]]::new()
    foreach ($statement in $Body.Statements) {
        if ($statement -isnot [System.Management.Automation.Language.IfStatementAst] -or $statement.Clauses.Count -ne 1 -or $statement.ElseClause) { break }
        $condition = $statement.Clauses[0].Item1.Extent.Text -replace '\s+', ' '
        $block = $statement.Clauses[0].Item2
        $matched = $false
        if ($condition -match '^(!|-not )\s*\(\s*Test-MtConnection\s+(-Service\s+)?([A-Za-z]+)\s*\)$' -and $ConnectionServices.ContainsKey($Matches[3])) {
            $service = $ConnectionServices[$Matches[3]]
            if (Test-SkipBody -Block $block) { $services.Add($service); $matched = $true }
        } else {
            $token = switch -Regex ($condition) {
                '^-not \(Get-MtLicenseInformation -Product Intune\)$' { 'INTUNE_A' ; break }
                '^\(\s*\(?\s*Get-MtLicenseInformation (-Product )?EntraID\s*\)?\s*\)? -eq [''"]Free[''"]$' { 'AAD_PREMIUM' ; break }
                '^\(\s*\(?\s*Get-MtLicenseInformation (-Product )?EntraID\s*\)?\s*\)? -ne [''"]P2[''"]$' { 'AAD_PREMIUM_P2' ; break }
                '^\(\s*Get-MtLicenseInformation (-Product )?EntraID\s*\) -eq [''"]Free[''"]$' { 'AAD_PREMIUM' ; break }
                '^\(\s*Get-MtLicenseInformation (-Product )?EntraID\s*\) -ne [''"]P2[''"]$' { 'AAD_PREMIUM_P2' ; break }
                '^[''"]P1[''"] -notin \(Get-MtLicenseInformation -Product MdoV2\)$' { 'ATP_ENTERPRISE' ; break }
                '^-not \(Get-MtLicenseInformation -Product Mdo\)$' { 'THREAT_INTELLIGENCE' ; break }
                '^\$null -eq \(Get-MtLicenseInformation -Product ExoDlp\)$' { 'EXCHANGE_DLP' ; break }
                default { $null }
            }
            if ($token -and (Test-SkipBody -Block $block)) { $licenses.Add($token); $matched = $true }
        }
        if (-not $matched) { break }
        $guards.Add($statement)
    }
    [pscustomobject]@{ Statements = $guards.ToArray(); Services = @($services | Select-Object -Unique); Licenses = @($licenses | Select-Object -Unique) }
}

function Get-OuterTry {
    # The outer try/catch whose catch only reports -SkippedBecause Error, when it is the last statement.
    param([System.Management.Automation.Language.NamedBlockAst] $Body, [object[]] $Guards)
    $rest = @($Body.Statements | Where-Object { $_ -notin $Guards })
    if ($rest.Count -lt 1) { return $null }
    $try = $rest[-1]
    if ($try -isnot [System.Management.Automation.Language.TryStatementAst] -or $try.CatchClauses.Count -ne 1 -or $try.Finally) { return $null }
    $catch = $try.CatchClauses[0]
    if ($catch.CatchTypes.Count -gt 0) { return $null }
    $statements = @($catch.Body.Statements)
    $hasReport = $false
    foreach ($s in $statements) {
        $text = $s.Extent.Text.Trim() -replace '\s+', ' '
        if ($text -match '^Add-MtTestResultDetail -SkippedBecause Error -SkippedError \$_$' -or $text -match '^Add-MtTestResultDetail -SkippedError \$_ -SkippedBecause Error$') { $hasReport = $true; continue }
        if ($text -match '^return( \$null)?$') { continue }
        if ($text -match '^Write-(Verbose|Error|Warning)\b') { continue }
        return $null
    }
    if (-not $hasReport) { return $null }
    $try
}

$ServiceInference = [ordered]@{
    'ActiveDirectory'    = '\b(Get-MtAD\w+|Get-MtADDomainState|Invoke-MtAD\w+)\b'
    'AzureDevOps'        = '\b(Get-ADOPS\w+|Invoke-ADOPS\w+|Get-MtAzureDevOps\w*)\b'
    'GitHub'             = '\bInvoke-MtGitHubRequest\b'
    'Teams'              = '\bGet-Cs\w+\b'
    'SharePointOnline'   = '\b(Get-MtSpo|Get-PnP\w+|Get-SPO\w+)\b'
    'SecurityCompliance' = '\b(Get-DlpCompliancePolicy|Get-Label\w*|Get-ProtectionAlert|Get-RetentionCompliance\w+)\b'
    'ExchangeOnline'     = '\b(Get-MtExo|Get-EXO\w+|Get-(Mailbox|OrganizationConfig|TransportRule|AdminAuditLogConfig|AcceptedDomain|HostedContentFilterPolicy|AntiPhishPolicy|SafeLinksPolicy|SafeAttachmentPolicy|DkimSigningConfig|RemoteDomain|SharingPolicy|OwaMailboxPolicy|ExternalInOutlook|ReportSubmissionPolicy|AtpPolicyForO365|MalwareFilterPolicy|HostedOutboundSpamFilterPolicy|InboundConnector|OutboundConnector)\w*)\b'
    'Azure'              = '\b(Invoke-MtAzureRequest|Invoke-MtAzureResourceGraphRequest|Get-AzContext|Invoke-AzRestMethod)\b'
    'Graph'              = '\b(Invoke-MtGraphRequest|Invoke-MgGraphRequest|Get-MgContext|Get-MtConditionalAccessPolicy|Get-MtUser|Get-MtRole\w*|Get-MtGroupMember|Get-MtLicenseInformation|Invoke-MtGraphSecurityQuery|Get-MtUserAuthenticationMethod\w*|Get-MtAuthenticationMethodPolicyConfig|Get-MtTrustedNamedLocationId|Get-MtEmergencyAccessAccount|Get-MtPrivateAccessApplication)\b'
}

function Get-InferredService {
    param([string] $Text)
    $found = foreach ($key in $ServiceInference.Keys) { if ($Text -match $ServiceInference[$key]) { $key } }
    if (-not $found) { return @('Graph') }
    @($found)
}

function Remove-BlankRun {
    # Collapses runs of blank lines (left where statements were removed) to one, keeping indentation.
    param([string] $Text)
    [regex]::Replace($Text, "\n([ \t]*\r?\n){2,}", "`n`n")
}

function Get-FunctionAst {
    param([string] $Text, [string] $Name)
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    if ($errors) { throw "the edited function does not parse: $($errors[0].Message)" }
    $definition = $ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $Name } | Select-Object -First 1
    [pscustomobject]@{ Definition = $definition; Tokens = $tokens }
}

function Remove-OuterTry {
    # Replaces 'try { body } catch { ... }' with the body, dedented one level. Lines inside multi-line
    # strings are not touched. Returns $null when the try is not laid out canonically.
    param([string] $Text, [System.Management.Automation.Language.TryStatementAst] $Try, [object[]] $Tokens)
    $lines = $Text -split "`n"
    $tryLine = $Try.Extent.StartLineNumber
    $bodyEndLine = $Try.Body.Extent.EndLineNumber
    $endLine = $Try.Extent.EndLineNumber
    if ($lines[$tryLine - 1].Trim() -notmatch '^try\s*\{$') { return $null }
    if ($lines[$bodyEndLine - 1].Trim() -notmatch '^\}') { return $null }
    if ($bodyEndLine -le $tryLine) { return $null }
    $protected = @{}
    foreach ($token in $Tokens) {
        if ($token.Kind -in 'StringLiteral', 'StringExpandable', 'HereStringLiteral', 'HereStringExpandable' -and $token.Extent.EndLineNumber -gt $token.Extent.StartLineNumber) {
            for ($l = $token.Extent.StartLineNumber + 1; $l -le $token.Extent.EndLineNumber; $l++) { $protected[$l] = $true }
        }
    }
    $tryIndent = $lines[$tryLine - 1].Length - $lines[$tryLine - 1].TrimStart().Length
    $firstCode = $null
    for ($l = $tryLine + 1; $l -lt $bodyEndLine; $l++) { if ($lines[$l - 1].Trim()) { $firstCode = $lines[$l - 1]; break } }
    if ($null -eq $firstCode) { return $null }
    $amount = ($firstCode.Length - $firstCode.TrimStart().Length) - $tryIndent
    if ($amount -lt 0) { $amount = 0 }
    $inner = for ($l = $tryLine + 1; $l -lt $bodyEndLine; $l++) {
        $line = $lines[$l - 1]
        if ($protected.ContainsKey($l)) { $line; continue }
        $strip = 0
        while ($strip -lt $amount -and $strip -lt $line.Length -and $line[$strip] -eq ' ') { $strip++ }
        $line.Substring($strip)
    }
    $before = if ($tryLine -gt 1) { $lines[0..($tryLine - 2)] } else { @() }
    $after = if ($endLine -lt $lines.Count) { $lines[$endLine..($lines.Count - 1)] } else { @() }
    (@($before) + @($inner) + @($after)) -join "`n"
}

function Format-StringValue { param([string] $Value) "'" + $Value.Replace("'", "''") + "'" }

function Format-ListValue {
    param([string[]] $Values)
    if ($Values.Count -eq 1) { return Format-StringValue $Values[0] }
    '(' + (($Values | ForEach-Object { Format-StringValue $_ }) -join ', ') + ')'
}

function New-AttributeText {
    param([hashtable] $Meta, [string] $Indent)
    $lines = [System.Collections.Generic.List[string]]::new()
    $add = { param($name, $value) $lines.Add("$Indent    $($name.PadRight(17)) = $value") }
    & $add 'Id' (Format-StringValue $Meta.Id)
    & $add 'Title' (Format-StringValue $Meta.Title)
    if ($Meta.Severity) { & $add 'Severity' (Format-StringValue $Meta.Severity) }
    & $add 'Category' (Format-StringValue $Meta.Category)
    if ($Meta.Tag.Count -gt 0) { & $add 'Tag' (Format-ListValue $Meta.Tag) }
    if ($Meta.Preview) { $lines.Add("$Indent    Preview") }
    if ($Meta.LongRunning) { $lines.Add("$Indent    LongRunning") }
    & $add 'Service' (Format-ListValue $Meta.Service)
    if ($Meta.CompatibleLicense.Count -gt 0) { & $add 'CompatibleLicense' (Format-ListValue $Meta.CompatibleLicense) }
    if ($Meta.Author.Count -gt 0) { & $add 'Author' (Format-ListValue $Meta.Author) }
    if ($Meta.Contributor.Count -gt 0) { & $add 'Contributor' (Format-ListValue $Meta.Contributor) }
    if ($Meta.HelpUrl) { & $add 'HelpUrl' (Format-StringValue $Meta.HelpUrl) }
    # Bare flags have no '=': fix the alignment of the named ones only.
    "$Indent[MaesterTest(`n" + (($lines | ForEach-Object { $_ -replace '^(\s+)(\w+)\s+= ', '$1$2 = ' }) -join ",`n") + "`n$Indent)]"
}

function Remove-Indent {
    param([string] $Text, [int] $Amount)
    ($Text -split "`n" | ForEach-Object {
            $line = $_
            $strip = 0
            while ($strip -lt $Amount -and $strip -lt $line.Length -and $line[$strip] -eq ' ') { $strip++ }
            $line.Substring($strip)
        }) -join "`n"
}

function Get-FunctionFile {
    param([string] $Name)
    $files = @(Get-ChildItem -Path (Join-Path $PowerShellRoot 'public'), (Join-Path $PowerShellRoot 'internal') -Recurse -File -Filter "$Name.ps1" -ErrorAction SilentlyContinue)
    if ($files.Count -eq 1) { return $files[0].FullName }
    $null
}

function Get-WrapperCall {
    # Classifies the body of a wrapper It. Returns Command, Arguments (text), Polarity ($true/$false) or $null.
    param([System.Management.Automation.Language.ScriptBlockAst] $Body)
    $statements = @($Body.EndBlock.Statements)
    $assign = $null
    $call = $null
    $polarity = $null
    $assertionText = $null
    foreach ($s in $statements) {
        $text = ($s.Extent.Text -replace '\s+', ' ').Trim()
        if ($s -is [System.Management.Automation.Language.AssignmentStatementAst] -and -not $assign) {
            $right = $s.Right
            if ($right -is [System.Management.Automation.Language.PipelineAst] -and $right.PipelineElements.Count -eq 1 -and $right.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) {
                $assign = $s.Left.Extent.Text
                $call = $right.PipelineElements[0]
                continue
            }
            return $null
        }
        if ($s -is [System.Management.Automation.Language.IfStatementAst] -and $assign -and $s.Clauses.Count -eq 1 -and -not $s.ElseClause -and
            ($s.Clauses[0].Item1.Extent.Text -replace '\s+', ' ') -in @("`$null -ne $assign", "$assign -ne `$null")) {
            $inner = @($s.Clauses[0].Item2.Statements)
            if ($inner.Count -ne 1) { return $null }
            $assertionText = ($inner[0].Extent.Text -replace '\s+', ' ').Trim()
            continue
        }
        if ($s -is [System.Management.Automation.Language.PipelineAst]) {
            if (-not $assign -and $s.PipelineElements.Count -eq 2 -and $s.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst] -and
                $s.PipelineElements[1].Extent.Text -match '^Should\b') {
                $call = $s.PipelineElements[0]
                $assertionText = '$x | ' + $s.PipelineElements[1].Extent.Text
                continue
            }
            if ($assign -and $text -like "$assign | Should*") { $assertionText = $text; continue }
        }
        return $null
    }
    if (-not $call -or -not $assertionText) { return $null }
    $assertion = ($assertionText -split '\|', 2)[1].Trim()
    if ($assertion -match '^Should (-Be \$true|-BeTrue)\b') { $polarity = $true }
    elseif ($assertion -match '^Should (-Be \$false|-BeFalse)\b') { $polarity = $false }
    else { return $null }
    $arguments = @($call.CommandElements | Select-Object -Skip 1)
    foreach ($a in $arguments) {
        if ($a -is [System.Management.Automation.Language.CommandParameterAst]) { if ($a.Argument -and $a.Argument -isnot [System.Management.Automation.Language.ConstantExpressionAst]) { return $null } ; continue }
        if ($a -isnot [System.Management.Automation.Language.ConstantExpressionAst] -and $a -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and
            -not ($a -is [System.Management.Automation.Language.VariableExpressionAst] -and $a.VariablePath.UserPath -in 'true', 'false')) { return $null }
    }
    [pscustomobject]@{
        Command   = $call.GetCommandName()
        Arguments = (($arguments | ForEach-Object { $_.Extent.Text }) -join ' ')
        Polarity  = $polarity
    }
}

function Get-SafeFunctionName {
    param([string] $TestId)
    'Test-MtCheck' + (($TestId -split '[^A-Za-z0-9]+' | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '')
}

# ---------------------------------------------------------------------------------------------- plan

$entries = @($Golden | Where-Object { -not $_.Family })
if ($Suite) { $entries = @($entries | Where-Object { (Get-SuiteFolder $_.File) -eq $Suite }) }
if ($Id) { $entries = @($entries | Where-Object { $_.Id -in $Id }) }
if ($entries.Count -eq 0) { throw 'No checks match the given -Id or -Suite.' }

# How many IDs call each function (a shared function needs Thin mode).
$callCount = @{}
foreach ($e in @($Golden | Where-Object { -not $_.Family })) {
    $file = Join-Path $RepoRoot $e.File
    if (-not (Test-Path $file)) { continue }
    $parsed = Get-Ast $file
    $it = $parsed.Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It' -and $n.Extent.StartLineNumber -eq $e.Line }, $true) | Select-Object -First 1
    if (-not $it) { continue }
    $body = $it.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } | Select-Object -Last 1
    if (-not $body) { continue }
    $c = Get-WrapperCall -Body $body.ScriptBlock
    if ($c) { $callCount[$c.Command] = 1 + [int]$callCount[$c.Command] }
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$configRows = @{}
foreach ($r in $config.TestSettings) { $configRows[$r.Id] = $r }

$report = [System.Collections.Generic.List[object]]::new()
$wrapperEdits = @{}   # wrapper file -> list of It extents to remove
$removeConfigIds = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $entries) {
    $item = [ordered]@{ Id = $entry.Id; Wrapper = $entry.File; Mode = $null; Function = $null; Target = $null; Flags = @(); Converted = $false }
    try {
        $wrapperPath = Join-Path $RepoRoot $entry.File
        if (-not (Test-Path $wrapperPath)) { throw 'wrapper file not found (already converted?)' }
        $wrapper = Get-Ast $wrapperPath
        $it = $wrapper.Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It' -and $n.Extent.StartLineNumber -eq $entry.Line }, $true) | Select-Object -First 1
        if (-not $it) { throw "It not found at line $($entry.Line)" }
        $flags = [System.Collections.Generic.List[string]]::new()
        foreach ($element in $it.CommandElements) {
            if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and $element.ParameterName -in 'Skip', 'ForEach', 'TestCases') { throw "the It uses -$($element.ParameterName); convert by hand" }
        }
        $body = $it.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } | Select-Object -Last 1
        $call = Get-WrapperCall -Body $body.ScriptBlock
        if (-not $call) { throw 'the It body is not a single check call with a boolean Should; convert by hand' }
        $functionFile = Get-FunctionFile -Name $call.Command
        if (-not $functionFile) { throw "function file for $($call.Command) not found" }
        $item.Function = $call.Command
        $thin = $call.Arguments -or -not $call.Polarity -or [int]$callCount[$call.Command] -gt 1
        $item.Mode = if ($thin) { 'Thin' } else { 'Move' }

        # Metadata.
        $suiteFolder = Get-SuiteFolder $entry.File
        $suiteTags = Get-SuiteTag $suiteFolder
        $titleInfo = Get-ItTitle -Name $entry.Name
        $selectionTags = @($entry.SelectionTags)
        $severity = $null
        if ($configRows.ContainsKey($entry.Id) -and $configRows[$entry.Id].Severity) { $severity = [string]$configRows[$entry.Id].Severity }
        if (-not $severity) { $sevTag = $selectionTags | Where-Object { $_ -like 'Severity:*' } | Select-Object -First 1; if ($sevTag) { $severity = ($sevTag -split ':', 2)[1].Trim() } }
        if (-not $severity) { $severity = 'Medium'; $flags.Add('NoSeverity: no severity in config or tags; set to Medium for review') }
        $tag = @($selectionTags | Where-Object { $_ -ne $entry.Id -and $_ -notin 'Preview', 'LongRunning' -and $_ -notin $suiteTags })
        $seedRow = $Seed[$entry.Id]
        $authors = if ($seedRow -and $seedRow.author) { @($seedRow.author -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
        $contributors = if ($seedRow -and $seedRow.contributors_recommended) { @($seedRow.contributors_recommended -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notin $authors }) } else { @() }
        if ($authors.Count -eq 0) { $authors = @('merill'); $flags.Add('NoAuthor: no author in the seed; set to merill for review') }
        $helpUrl = if ($titleInfo.Url -and $titleInfo.Url -ne "https://maester.dev/docs/tests/$($entry.Id)") { $titleInfo.Url } else { $null }

        # Function analysis.
        $function = Get-Ast $functionFile
        $definition = $function.Ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $call.Command } | Select-Object -First 1
        if (-not $definition) { throw "function $($call.Command) not found in $functionFile" }
        $otherTopLevel = @($function.Ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] })
        if ($otherTopLevel.Count -gt 0) { throw "the function file has top-level statements other than functions; convert by hand" }
        $namedBody = $definition.Body.EndBlock
        $guards = Get-GuardInfo -Body $namedBody
        $services = if ($guards.Services.Count -gt 0) { @($guards.Services) } else { @(Get-InferredService -Text $definition.Extent.Text) }
        if ($guards.Services.Count -eq 0) { $flags.Add("InferredService: $($services -join ', ')") }
        if ($namedBody.Statements | Where-Object { $_ -notin $guards.Statements -and $_.Extent.Text -match 'Get-MtLicenseInformation|Test-MtConnection' -and $_ -isnot [System.Management.Automation.Language.TryStatementAst] }) {
            $flags.Add('KeptGuard: a non-canonical connection or licence check remains in the body')
        }

        # New function text, in three passes, each on a fresh parse: guards removed, outer try unwrapped,
        # attribute inserted (Move mode).
        $text = $function.Text
        foreach ($g in ($guards.Statements | Sort-Object { $_.Extent.StartOffset } -Descending)) {
            $text = $text.Substring(0, $g.Extent.StartOffset) + $text.Substring($g.Extent.EndOffset)
        }
        $text = Remove-BlankRun $text
        $reparsed = Get-FunctionAst -Text $text -Name $call.Command
        $outerTry = Get-OuterTry -Body $reparsed.Definition.Body.EndBlock -Guards @()
        if ($outerTry) {
            $unwrapped = Remove-OuterTry -Text $text -Try $outerTry -Tokens $reparsed.Tokens
            if ($unwrapped) { $text = Remove-BlankRun $unwrapped } else { $outerTry = $null }
        }
        if (-not $outerTry -and -not ($flags -like 'KeptTry*')) { $flags.Add('KeptTry: no canonical outer try/catch to remove') }
        $reparsed = Get-FunctionAst -Text $text -Name $call.Command
        $definition = $reparsed.Definition
        $paramBlock = $definition.Body.ParamBlock
        $meta = @{
            Id = $entry.Id; Title = $titleInfo.Title; Severity = $severity; Category = $entry.Block; Tag = $tag
            Preview = $selectionTags -contains 'Preview'; LongRunning = $selectionTags -contains 'LongRunning'
            Service = $services; CompatibleLicense = @($guards.Licenses); Author = $authors; Contributor = $contributors; HelpUrl = $helpUrl
        }

        $targetDir = Split-Path (Join-Path $RepoRoot $entry.File) -Parent
        $targetPs1 = Join-Path $targetDir "Test.$($entry.Id).ps1"
        $targetMd = Join-Path $targetDir "Test.$($entry.Id).md"
        $sourceMd = [System.IO.Path]::ChangeExtension($functionFile, '.md')
        $item.Target = $targetPs1.Substring($RepoRoot.Length + 1) -replace '\\', '/'
        if (Test-Path $targetPs1) { throw "target $targetPs1 already exists" }

        if (-not $thin) {
            # Move mode: the check function itself becomes the native test.
            if (-not $paramBlock) { throw 'the function has no param() block; convert by hand' }
            $cmdletBinding = $paramBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' } | Select-Object -First 1
            $anchor = if ($cmdletBinding) { $cmdletBinding } elseif ($paramBlock.Attributes.Count -gt 0) { $paramBlock.Attributes[0] } else { $paramBlock }
            $indent = ' ' * ($anchor.Extent.StartColumnNumber - 1)
            $attributeText = New-AttributeText -Meta $meta -Indent $indent
            $insert = $attributeText.TrimStart() + "`n" + $indent
            if (-not $cmdletBinding) { $insert += "[CmdletBinding()]`n$indent"; $flags.Add('AddedCmdletBinding') }
            $text = $text.Substring(0, $anchor.Extent.StartOffset) + $insert + $text.Substring($anchor.Extent.StartOffset)
            $newPs1 = $text
            $helperTarget = $null
        } else {
            # Thin mode: the function becomes an internal helper (guards and outer try removed) and a thin
            # test with a new name calls it with the wrapper's literal arguments.
            $relative = $functionFile.Substring((Join-Path $PowerShellRoot 'public').Length).TrimStart('\', '/')
            $helperTarget = if ($functionFile -like "*$([System.IO.Path]::DirectorySeparatorChar)internal$([System.IO.Path]::DirectorySeparatorChar)*") { $functionFile } else { Join-Path $PowerShellRoot "internal/checks/$relative" }
            $thinName = Get-SafeFunctionName -TestId $entry.Id
            $callLine = "$($call.Command) $($call.Arguments)".Trim()
            $resultLine = if ($call.Polarity) { 'return $result' } else { "# The shared check returns `$true when the tenant is not compliant.`n    return (-not `$result)" }
            $newPs1 = @"
function $thinName {
    <#
    .SYNOPSIS
    $($titleInfo.Title)

    .DESCRIPTION
    Runs the shared check $($call.Command)$(if ($call.Arguments) { " with $($call.Arguments)" }).
    #>
$(New-AttributeText -Meta $meta -Indent '    ')
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    `$result = $callLine
    if (`$null -eq `$result) { return `$null }
    $resultLine
}
"@
            $item.Function = "$thinName -> $($call.Command)"
        }

        # Markdown.
        $mdText = if (Test-Path $sourceMd) { [System.IO.File]::ReadAllText($sourceMd) } else {
            $flags.Add('GeneratedMarkdown: no .md file; generated from the function help')
            $help = $definition.GetHelpContent()
            $desc = if ($help -and $help.Description) { $help.Description.Trim() } elseif ($help -and $help.Synopsis) { $help.Synopsis.Trim() } else { $titleInfo.Title }
            "$desc`n`n#### Remediation action`n`nReview the configuration described above.`n"
        }
        if ($mdText -notmatch '<!--- Results --->') { $mdText = $mdText.TrimEnd() + "`n`n<!--- Results --->`n%TestResult%`n" }

        $item.Flags = $flags.ToArray()
        $item.Severity = $severity
        $item.Service = $services
        $item.CompatibleLicense = @($guards.Licenses)
        $item.RemovedGuards = $guards.Statements.Count
        $item.RemovedTry = [bool]$outerTry

        if (-not $WhatIf) {
            if ($thin) {
                if ($helperTarget -ne $functionFile) {
                    $null = New-Item -ItemType Directory -Path (Split-Path $helperTarget) -Force
                    & git -C $RepoRoot mv $functionFile $helperTarget
                    if (Test-Path $sourceMd) { & git -C $RepoRoot mv $sourceMd ([System.IO.Path]::ChangeExtension($helperTarget, '.md')) }
                }
                [System.IO.File]::WriteAllText($helperTarget, $text, [System.Text.UTF8Encoding]::new($true))
                [System.IO.File]::WriteAllText($targetPs1, $newPs1, [System.Text.UTF8Encoding]::new($true))
                $helperMd = [System.IO.Path]::ChangeExtension($helperTarget, '.md')
                if (Test-Path $helperMd) { Copy-Item $helperMd $targetMd } else { [System.IO.File]::WriteAllText($targetMd, $mdText, [System.Text.UTF8Encoding]::new($true)) }
                $copied = [System.IO.File]::ReadAllText($targetMd)
                if ($copied -notmatch '<!--- Results --->') { [System.IO.File]::WriteAllText($targetMd, $copied.TrimEnd() + "`n`n<!--- Results --->`n%TestResult%`n", [System.Text.UTF8Encoding]::new($true)) }
            } else {
                & git -C $RepoRoot mv $functionFile $targetPs1
                [System.IO.File]::WriteAllText($targetPs1, $newPs1, [System.Text.UTF8Encoding]::new($true))
                if (Test-Path $sourceMd) { & git -C $RepoRoot mv $sourceMd $targetMd }
                [System.IO.File]::WriteAllText($targetMd, $mdText, [System.Text.UTF8Encoding]::new($true))
            }
            if (-not $wrapperEdits.ContainsKey($wrapperPath)) { $wrapperEdits[$wrapperPath] = [System.Collections.Generic.List[object]]::new() }
            $wrapperEdits[$wrapperPath].Add($it)
            $removeConfigIds.Add($entry.Id)
        }
        $item.Converted = $true
    } catch {
        $item.Flags = @($item.Flags) + "Manual: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
    }
    $report.Add([pscustomobject]$item)
}

# Remove the converted It blocks from their wrappers (bottom up), and empty wrappers.
foreach ($wrapperPath in $wrapperEdits.Keys) {
    $text = [System.IO.File]::ReadAllText($wrapperPath)
    foreach ($it in ($wrapperEdits[$wrapperPath] | Sort-Object { $_.Extent.StartOffset } -Descending)) {
        $start = $it.Extent.StartOffset
        $lineStart = $text.LastIndexOf("`n", [Math]::Max(0, $start - 1)) + 1
        $end = $it.Extent.EndOffset
        $lineEnd = $text.IndexOf("`n", $end); if ($lineEnd -lt 0) { $lineEnd = $text.Length } else { $lineEnd++ }
        $text = $text.Substring(0, $lineStart) + $text.Substring($lineEnd)
    }
    $parsed = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)
    $remainingIts = $parsed.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It' }, $true)
    if (@($remainingIts).Count -eq 0) {
        & git -C $RepoRoot rm -q $wrapperPath
    } else {
        [System.IO.File]::WriteAllText($wrapperPath, $text, [System.Text.UTF8Encoding]::new($true))
    }
}

# Remove the converted rows from the shipped config.
if ($removeConfigIds.Count -gt 0) {
    $raw = [System.IO.File]::ReadAllText($ConfigPath)
    $json = $raw | ConvertFrom-Json
    $json.TestSettings = @($json.TestSettings | Where-Object { $_.Id -notin $removeConfigIds })
    $out = $json | ConvertTo-Json -Depth 10
    $bom = [System.IO.File]::ReadAllBytes($ConfigPath)[0] -eq 0xEF
    [System.IO.File]::WriteAllText($ConfigPath, ($out -replace "`r`n", "`n") + "`n", [System.Text.UTF8Encoding]::new($bom))
}

if (-not $ReportPath) {
    $reports = Join-Path $PSScriptRoot 'reports'
    $null = New-Item -ItemType Directory -Path $reports -Force
    $ReportPath = Join-Path $reports ("convert-" + $(if ($Suite) { $Suite } else { 'ids' }) + '.json')
}
$null = New-Item -ItemType Directory -Path (Split-Path $ReportPath -Parent) -Force
$report | ConvertTo-Json -Depth 5 | Set-Content -Path $ReportPath -Encoding utf8
$converted = @($report | Where-Object Converted).Count
Write-Host "Converted $converted of $($report.Count) check(s). Report: $ReportPath"
$report | Where-Object { -not $_.Converted } | ForEach-Object { Write-Host "  manual: $($_.Id) - $(($_.Flags | Where-Object { $_ -like 'Manual:*' }) -join '; ')" -ForegroundColor Yellow }
