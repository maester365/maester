function Get-MtArgumentCompletion {
    <#
    .SYNOPSIS
    Returns the Tab completions for one parameter of a Maester command (the completer Register-MtArgumentCompleter registers).

    .DESCRIPTION
    Looks the parameter up in Get-MtArgumentCompleterTable, lists the candidates of its kind
    (Get-MtCompletionCandidate) and returns those that match the word being completed, best first:

    1. the value starts with the word (or matches it, when the word has a '*' or '?' wildcard);
    2. another name of the value starts with it: an alias, a display name or a requirement a test implements;
    3. every word of the search appears in the value, its other names or its description (for a word of three
       characters or more).

    Within a rank the candidates keep the order the kind gives them. Values already given earlier in the same
    parameter's list are left out. A word typed in quotes keeps them (ConvertTo-MtCompletionResult).

    Completion must never break the command line: nothing is written to the warning, information or progress
    streams, and on an error nothing is returned (the error goes to Write-Debug).
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CompletionResult])]
    param(
        [Parameter(Mandatory)] [string] $CommandName,
        [Parameter(Mandatory)] [string] $ParameterName,
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $WordToComplete = '',
        [Parameter()] [AllowNull()] [System.Collections.IDictionary] $FakeBoundParameters
    )

    $WarningPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    $ProgressPreference = 'SilentlyContinue'
    try {
        $row = Get-MtArgumentCompleterTable | Where-Object { $_.Command -eq $CommandName -and $_.Parameter -eq $ParameterName } | Select-Object -First 1
        if (-not $row) { return }

        # PowerShell 7 passes only the element being completed; another host may pass the whole list. A word typed
        # in quotes arrives with them, and with the closing quote PowerShell adds.
        $text = [string]$WordToComplete
        if ($text.Contains(',')) { $text = $text.Substring($text.LastIndexOf(',') + 1) }
        $text = $text.TrimStart()
        $quote = $null
        if ($text.Length -gt 0 -and ($text[0] -eq "'" -or $text[0] -eq '"')) {
            $quote = [string]$text[0]
            $text = $text.Substring(1)
            if ($text.EndsWith($quote)) { $text = $text.Substring(0, $text.Length - 1) }
        }

        # The other parameters on the line narrow the list; this one's earlier values are left out of it.
        $bound = @{}
        if ($FakeBoundParameters) { foreach ($key in $FakeBoundParameters.Keys) { $bound[[string]$key] = $FakeBoundParameters[$key] } }
        $taken = @(@($bound[$ParameterName]) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -ne $text })
        $bound.Remove($ParameterName)
        if (-not $row.Narrow) {
            # Only what decides which tests there are, not the selectors.
            $source = @{}
            foreach ($key in 'Path', 'PackLock', 'Pack', 'AllPacks', 'SkipBuiltIn') { if ($bound.ContainsKey($key)) { $source[$key] = $bound[$key] } }
            $bound = $source
        }

        $candidates = @(Get-MtCompletionCandidate -Kind $row.Kind -CommandName $CommandName -Word $text -BoundParameters $bound -Value $row.Values)
        $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase
        $words = @($text -split '\s+' | Where-Object { $_ })
        $wildcard = $text.IndexOfAny([char[]]'*?') -ge 0
        # A search inside names and titles needs three letters: 'en' would find defender.
        $search = $text.Length -ge 3
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($value in $taken) { $null = $seen.Add($value) }
        # Plain loops: a test ID lists hundreds of candidates.
        $ranked = foreach ($c in $candidates) {
            if (-not $seen.Add($c.Value)) { continue }
            $rank = 0
            if (-not $text) { $rank = 1 }
            elseif ($wildcard) { if ($c.Value -like "$text*") { $rank = 1 } }
            elseif ($c.Value.StartsWith($text, $ignoreCase)) { $rank = 1 }
            else {
                foreach ($name in $c.Match) { if ($name -and ([string]$name).StartsWith($text, $ignoreCase)) { $rank = 2; break } }
                if ($rank -eq 0 -and $search) {
                    $haystack = "$($c.Value) $($c.Match -join ' ') $($c.Search)"
                    $rank = 3
                    foreach ($w in $words) { if ($haystack.IndexOf($w, $ignoreCase) -lt 0) { $rank = 0; break } }
                }
            }
            if ($rank -gt 0) { [pscustomobject]@{ Rank = $rank; Order = $c.Order; Candidate = $c } }
        }
        foreach ($r in @($ranked | Sort-Object -Property Rank, Order)) {
            ConvertTo-MtCompletionResult -Value $r.Candidate.Value -ListItemText $r.Candidate.ListItem -ToolTip $r.Candidate.ToolTip -Quote $quote
        }
    } catch {
        Write-Debug "Tab completion of -$ParameterName for $CommandName failed: $($_.Exception.Message)"
    }
}
