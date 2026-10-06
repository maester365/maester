function ConvertTo-MtNativeFunctionBody {
    <#
    .SYNOPSIS
    Returns the text of a check function with the guards the engine now handles removed (used by Convert-MtTest).

    .DESCRIPTION
    Removes a leading 'if (-not (Test-MtConnection X)) { ... return ... }' guard and returns X as the Service
    of the test, and removes an outer try/catch whose catch only reports -SkippedBecause Error (the engine
    reports an exception as an Error row). Returns Text, Service and Notes.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Returns text only.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.FunctionDefinitionAst] $Definition
    )

    $notes = [System.Collections.Generic.List[string]]::new()
    $services = [System.Collections.Generic.List[string]]::new()
    $edits = [System.Collections.Generic.List[object]]::new()
    $origin = $Definition.Extent.StartOffset
    $statements = @($Definition.Body.EndBlock.Statements)

    foreach ($statement in $statements) {
        if ($statement -is [System.Management.Automation.Language.IfStatementAst] -and $statement.Clauses.Count -eq 1 -and -not $statement.ElseClause -and
            $statement.Clauses[0].Item1.Extent.Text -match '^\(?\s*-not\s*\(?\s*Test-MtConnection\b' -and $statement.Clauses[0].Item2.Extent.Text -match '\breturn\b') {
            foreach ($name in (Get-MtNativeServiceGuess -Text $statement.Clauses[0].Item1.Extent.Text)) { if (-not $services.Contains($name)) { $services.Add($name) } }
            $edits.Add([pscustomobject]@{ Start = $statement.Extent.StartOffset - $origin; End = $statement.Extent.EndOffset - $origin; Text = '' })
            continue
        }
        if ($statement -is [System.Management.Automation.Language.TryStatementAst] -and $statement.CatchClauses.Count -eq 1 -and -not $statement.Finally -and
            $statement.CatchClauses[0].Body.Extent.Text -match '-SkippedBecause\s+Error' -and $statement.CatchClauses[0].Body.Statements.Count -le 2) {
            $inner = $statement.Body.Extent.Text
            $inner = $inner.Substring(1, $inner.Length - 2).Trim("`r", "`n")
            $edits.Add([pscustomobject]@{ Start = $statement.Extent.StartOffset - $origin; End = $statement.Extent.EndOffset - $origin; Text = $inner.TrimStart() })
            continue
        }
        break
    }
    if ($services.Count -eq 0) {
        foreach ($name in (Get-MtNativeServiceGuess -Text $Definition.Body.Extent.Text)) { $services.Add($name) }
        if ($services.Count -gt 0) { $notes.Add("Service '$($services -join ', ')' was guessed from the code; check it.") }
    }

    $text = $Definition.Extent.Text
    foreach ($edit in ($edits | Sort-Object Start -Descending)) {
        $text = $text.Substring(0, $edit.Start) + $edit.Text + $text.Substring($edit.End)
    }
    # Blank lines left where a guard was removed.
    $text = [regex]::Replace($text, "(\r?\n[ \t]*){3,}", "`n`n", 'None', [timespan]::FromSeconds(5))
    [pscustomobject]@{ Text = $text; Service = $services.ToArray(); Notes = $notes.ToArray() }
}

function Get-MtNativeServiceGuess {
    <#
    .SYNOPSIS
    Returns the services a piece of check code uses: names passed to Test-MtConnection, else Graph for Graph calls.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text
    )

    $registry = Get-MtServiceRegistry
    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Text, 'Test-MtConnection\s+(?:-Service\s+)?[''"]?([A-Za-z]+)', 'IgnoreCase', [timespan]::FromSeconds(5))) {
        $name = Resolve-MtServiceName -Name $match.Groups[1].Value -Registry $registry
        if ($name -and -not $found.Contains($name)) { $found.Add($name) }
    }
    if ($found.Count -eq 0 -and $Text -match '\b(Invoke-MtGraphRequest|Invoke-MgGraphRequest|Get-Mg[A-Z]\w*|Get-MtConditionalAccessPolicy)\b') { $found.Add('Graph') }
    $found.ToArray()
}

function New-MtTestAttributeText {
    <#
    .SYNOPSIS
    Returns the text of a [MaesterTest(...)] attribute (used by Convert-MtTest).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Returns text only.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Id,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter()] [string] $Severity = 'Medium',
        [Parameter()] [string] $Category,
        [Parameter()] [string[]] $Tag,
        [Parameter()] [switch] $Preview,
        [Parameter()] [switch] $LongRunning,
        [Parameter()] [string[]] $Service,
        [Parameter()] [string] $HelpUrl
    )

    $quote = { param($value) "'" + ([string]$value).Replace("'", "''") + "'" }
    $list = { param($values) if (@($values).Count -eq 1) { & $quote @($values)[0] } else { '(' + ((@($values) | ForEach-Object { & $quote $_ }) -join ', ') + ')' } }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("    Id = $(& $quote $Id)")
    $lines.Add("    Title = $(& $quote $Title)")
    $lines.Add("    Severity = $(& $quote $Severity)")
    if ($Category) { $lines.Add("    Category = $(& $quote $Category)") }
    if (@($Tag).Count -gt 0) { $lines.Add("    Tag = $(& $list $Tag)") }
    if ($Preview) { $lines.Add('    Preview = $true') }
    if ($LongRunning) { $lines.Add('    LongRunning = $true') }
    if (@($Service).Count -gt 0) { $lines.Add("    Service = $(& $list $Service)") }
    if ($HelpUrl) { $lines.Add("    HelpUrl = $(& $quote $HelpUrl)") }
    "[MaesterTest(`n" + ($lines -join ",`n") + "`n)]"
}
