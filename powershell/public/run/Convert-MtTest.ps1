function Convert-MtTest {
    <#
    .SYNOPSIS
    Converts custom Pester-format Maester tests to the native format (Test.<ID>.ps1 and Test.<ID>.md).

    .DESCRIPTION
    Reads the *.Tests.ps1 files in a folder from their AST (no test code runs) and writes one native test
    per It block:

    - An It whose body calls one function defined in a .ps1 file of the same folder and checks the result
      with a boolean Should (the documented split-file pattern) becomes a native test containing that
      function, with the [MaesterTest] attribute added. A leading Test-MtConnection guard becomes the
      Service property, and an outer try/catch that only reports -SkippedBecause Error is removed: the
      engine does both. When the It passes arguments, the function is kept as a private helper in the
      file and the test calls it with those arguments.
    - An It with inline logic becomes a function whose body is the It body, with a trailing
      '<value> | Should -Be $true' rewritten to 'return <value>'. Other assertions, -ForEach and
      -TestCases data, BeforeDiscovery data and Set-ItResult are left in place with a TODO comment and
      listed in the report.

    The It name gives the ID and title (an ID without a prefix such as CT0001 is kept; the report suggests a
    prefix), the Describe name gives the category, and the tags are kept. The Markdown comes from the
    function's .md file, else from -Description in the code or the function's help.

    The original Pester files are not changed. Once a test is converted, Invoke-Maester runs the native test
    and does not run the Pester test with the same ID. Delete the Pester file when you are satisfied.

    .PARAMETER Path
    The folder with the Pester-format custom tests. Subfolders are included.

    .PARAMETER OutputPath
    The folder to write the native tests to. Defaults to -Path.

    .PARAMETER Force
    Overwrites native test files that already exist.

    .EXAMPLE
    Convert-MtTest -Path ./Custom -WhatIf

    Shows which tests would be converted and what needs attention, without writing anything.

    .EXAMPLE
    Convert-MtTest -Path ./Custom | Format-Table Id, Status, Notes

    Converts the custom tests and shows the report.

    .LINK
    https://maester.dev/docs/commands/Convert-MtTest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        [Parameter()]
        [string] $OutputPath,

        [Parameter()]
        [switch] $Force
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Error "The folder '$Path' does not exist."; return }
    $Path = (Resolve-Path -LiteralPath $Path).Path
    if (-not $OutputPath) { $OutputPath = $Path }
    Write-Verbose "Convert-MtTest: $Path -> $OutputPath"
    $schema = Get-MtTestSchema

    # Functions defined in the folder's plain .ps1 files (the split-file pattern).
    $functions = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' -and $_.Name -notlike 'Test.*.ps1' }) {
        $parsed = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        foreach ($f in $parsed.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
            $functions[$f.Name] = [pscustomobject]@{ Definition = $f; File = $file.FullName }
        }
    }

    foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.Tests.ps1') {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        if ($errors) {
            [pscustomobject]@{ Id = $null; Source = $file.FullName; Output = $null; Status = 'Skipped'; Notes = "The file does not parse: $($errors[0].Message)" }
            continue
        }
        $hasBeforeDiscovery = [bool]$ast.Find({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'BeforeDiscovery' }, $true)
        $its = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'It' }, $true)
        foreach ($it in $its) {
            $info = Get-MtPesterBlockArgument -CommandAst $it
            $notes = [System.Collections.Generic.List[string]]::new()
            if ($info.NameAst -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $info.NameAst.Value -match '<') {
                [pscustomobject]@{ Id = $null; Source = "$($file.FullName):$($it.Extent.StartLineNumber)"; Output = $null; Status = 'Skipped'; Notes = 'The test name is built at run time; convert it by hand to a family (InstanceSource).' }
                continue
            }
            $name = $info.NameAst.Value
            $url = $null
            $seeAt = $name.IndexOf('See https')
            if ($seeAt -gt 0) { $url = $name.Substring($seeAt + 4).Trim(); $name = $name.Substring(0, $seeAt).Trim() }
            $colon = $name.IndexOf(':')
            $id = if ($colon -gt 0) { $name.Substring(0, $colon).Trim() } else { $name.Trim() }
            $title = if ($colon -gt 0) { $name.Substring($colon + 1).Trim() } else { $name.Trim() }
            if ($id -notmatch $schema.IdPattern -or $id.Length -gt $schema.IdMaxLength) {
                [pscustomobject]@{ Id = $id; Source = "$($file.FullName):$($it.Extent.StartLineNumber)"; Output = $null; Status = 'Skipped'; Notes = "'$id' is not a valid test ID; name the It '<ID>: <title>', for example 'CONTOSO.1001: ...'." }
                continue
            }
            if ($id -notmatch '[.\-]') { $notes.Add("Consider a prefix for '$id', for example CONTOSO.$id.") }
            if ($schema.ReservedPrefixes | Where-Object { $id.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) { $notes.Add("The prefix of '$id' belongs to the built-in tests; a native test with a built-in ID is not run.") }

            # Describe (category) and tags.
            $tags = [System.Collections.Generic.List[string]]::new()
            $category = 'Custom'
            for ($p = $it.Parent; $p; $p = $p.Parent) {
                if ($p -is [System.Management.Automation.Language.CommandAst] -and $p.GetCommandName() -in 'Describe', 'Context') {
                    $block = Get-MtPesterBlockArgument -CommandAst $p
                    foreach ($t in $block.Tags) { $tags.Insert(0, $t) }
                    if ($p.GetCommandName() -eq 'Describe' -and $block.NameAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $category = $block.NameAst.Value }
                }
            }
            foreach ($t in $info.Tags) { $tags.Add($t) }
            $severity = ($tags | Where-Object { $_ -like 'Severity:*' } | Select-Object -First 1)
            $severity = if ($severity) { ($severity -split ':', 2)[1].Trim() } else { 'Medium' }
            $cleanTags = @($tags | Where-Object { $_ -ne $id -and $_ -notin 'Preview', 'LongRunning' } | Select-Object -Unique)
            if ($info.HasForEach) { $notes.Add('The It uses -ForEach or -TestCases; review the converted test.') }
            if ($hasBeforeDiscovery) { $notes.Add('The file uses BeforeDiscovery; data it prepares is not available to the native test.') }

            $body = ($it.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } | Select-Object -Last 1).ScriptBlock
            $statements = @($body.EndBlock.Statements)
            $helpers = [System.Collections.Generic.List[string]]::new()
            $service = @()
            $functionText = $null
            $markdown = $null
            $status = 'Converted'

            # Split-file pattern: one call to a folder function, checked with a boolean Should.
            $call = $null
            $polarity = $null
            if ($statements.Count -eq 1 -and $statements[0] -is [System.Management.Automation.Language.PipelineAst] -and $statements[0].PipelineElements.Count -eq 2 -and
                $statements[0].PipelineElements[0] -is [System.Management.Automation.Language.CommandAst] -and
                $functions.ContainsKey([string]$statements[0].PipelineElements[0].GetCommandName())) {
                $assert = $statements[0].PipelineElements[1].Extent.Text
                if ($assert -match '^Should\s+(-Be\s+\$true|-BeTrue)\b') { $polarity = $true } elseif ($assert -match '^Should\s+(-Be\s+\$false|-BeFalse)\b') { $polarity = $false }
                if ($null -ne $polarity) { $call = $statements[0].PipelineElements[0] }
            }

            $functionName = 'Test-' + (($id -split '[^A-Za-z0-9]+' | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '')
            if ($call) {
                $source = $functions[$call.GetCommandName()]
                $definition = $source.Definition
                $converted = ConvertTo-MtNativeFunctionBody -Definition $definition
                $service = $converted.Service
                if ($converted.Notes) { foreach ($n in $converted.Notes) { $notes.Add($n) } }
                $sourceMd = [System.IO.Path]::ChangeExtension($source.File, '.md')
                if (Test-Path -LiteralPath $sourceMd) { $markdown = Get-Content -LiteralPath $sourceMd -Raw }
                $arguments = @($call.CommandElements | Select-Object -Skip 1)
                if ($arguments.Count -eq 0 -and $polarity) {
                    $functionName = $definition.Name
                    $functionText = $converted.Text
                } else {
                    $helpers.Add($converted.Text)
                    $callText = $call.Extent.Text
                    $return = if ($polarity) { 'return $result' } else { 'return (-not $result)' }
                    $functionText = "function $functionName {`n    [CmdletBinding()]`n    param()`n`n    `$result = $callText`n    if (`$null -eq `$result) { return `$null }`n    $return`n}"
                }
                $helpText = $definition.GetHelpContent()
                if (-not $markdown -and $helpText) { $markdown = (@($helpText.Synopsis, $helpText.Description) | Where-Object { $_ }) -join "`n`n" }
            } else {
                # Inline logic: the It body becomes the function body.
                $text = $body.Extent.Text
                $text = $text.Substring(1, $text.Length - 2)
                $lines = $text -split "`r?`n"
                $out = [System.Collections.Generic.List[string]]::new()
                foreach ($line in $lines) {
                    if ($line -match '^(\s*)(.+?)\s*\|\s*Should\s+(-Be\s+\$true|-BeTrue)\b.*$') { $out.Add("$($Matches[1])return ($($Matches[2]))"); continue }
                    if ($line -match '^(\s*)(.+?)\s*\|\s*Should\s+(-Be\s+\$false|-BeFalse)\b.*$') { $out.Add("$($Matches[1])return (-not ($($Matches[2])))"); continue }
                    if ($line -match '\bShould\b|\bSet-ItResult\b') {
                        $out.Add("$line # TODO (Convert-MtTest): Pester assertion; return `$true or `$false instead")
                        $status = 'NeedsReview'
                        continue
                    }
                    $out.Add($line)
                }
                if ($status -eq 'NeedsReview') { $notes.Add('The test has assertions that could not be rewritten; see the TODO comments.') }
                $inner = ($out -join "`n").Trim("`r", "`n")
                $functionText = "function $functionName {`n    [CmdletBinding()]`n    param()`n`n$inner`n}"
                $service = @(Get-MtNativeServiceGuess -Text $inner)
            }
            if (-not $markdown) {
                $description = ($it.Extent.Text | Select-String -Pattern "-Description\s+(['""])(.+?)\1" -AllMatches).Matches | Select-Object -First 1
                $markdown = if ($description) { $description.Groups[2].Value } else { $title }
                $notes.Add('The Markdown file was generated; add a description and remediation steps.')
            }
            if ($markdown -notmatch '<!--- Results --->') { $markdown = $markdown.TrimEnd() + "`n`n<!--- Results --->`n%TestResult%`n" }

            $attribute = New-MtTestAttributeText -Id $id -Title $title -Severity $severity -Category $category -Tag $cleanTags `
                -Preview:($tags -contains 'Preview') -LongRunning:($tags -contains 'LongRunning') -Service $(if ($service) { $service } else { @('None') }) -HelpUrl $(if ($url -and $url -notlike '*maester.dev/docs/tests/*') { $url } else { $null })
            # The attribute goes above [CmdletBinding()] of the test function.
            $functionText = [regex]::Replace($functionText, "(?m)^(\s*)\[CmdletBinding\(", { param($m) "$($m.Groups[1].Value)$($attribute.Replace("`n", "`n$($m.Groups[1].Value)"))`n$($m.Groups[1].Value)[CmdletBinding(" }, 'None', [timespan]::FromSeconds(5))
            if ($functionText -notmatch '\[MaesterTest\(') {
                $functionText = $functionText -replace "(?s)^(function [^\{]+\{)", "`$1`n    $($attribute.Replace("`n", "`n    "))`n    [CmdletBinding()]"
            }
            $content = (@($functionText) + @($helpers)) -join "`n`n"
            $target = Join-Path $OutputPath "Test.$id.ps1"
            $targetMd = Join-Path $OutputPath "Test.$id.md"
            if ((Test-Path -LiteralPath $target) -and -not $Force) {
                [pscustomobject]@{ Id = $id; Source = "$($file.FullName):$($it.Extent.StartLineNumber)"; Output = $target; Status = 'Skipped'; Notes = 'The native test already exists; use -Force to overwrite it.' }
                continue
            }
            if ($PSCmdlet.ShouldProcess($target, "Write native test $id")) {
                $null = New-Item -ItemType Directory -Path $OutputPath -Force
                Set-Content -LiteralPath $target -Value $content -Encoding utf8
                Set-Content -LiteralPath $targetMd -Value $markdown -Encoding utf8
                $check = Read-MtNativeTest -Path $target
                if ($check.Errors.Count -gt 0) { $status = 'NeedsReview'; $notes.Add("Validation: $(($check.Errors | ForEach-Object { $_.Message }) -join ' ')") }
            }
            [pscustomobject]@{ Id = $id; Source = "$($file.FullName):$($it.Extent.StartLineNumber)"; Output = $target; Status = $status; Notes = ($notes -join ' ') }
        }
    }
}
