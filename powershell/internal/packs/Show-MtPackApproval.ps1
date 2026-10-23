function Show-MtPackApproval {
    <#
    .SYNOPSIS
    Shows the install prompt for a pack and returns whether it was approved (Maester Packs design, section 5.3).

    .DESCRIPTION
    Prints what the pack is, where it comes from, what it adds and reaches, how old the content is and its
    risk level from the local scan, then asks. Everything that comes from the pack is cleaned
    (ConvertTo-MtPackSafeText) and Maester's own lines (Risk, Reaches, Microsoft, Cooldown and the question)
    come last, so text in a pack cannot redraw them.

    - Low risk: Yes or No, default No. -Force answers Yes.
    - Medium risk: the findings are listed; without a console, -AcceptRisk Medium (or High) is required.
    - High risk, or content younger than the release cooldown: the pack code must be typed to confirm;
      without a console, -AcceptRisk High or -IncludeRecent is required. -Force never answers these.

    Returns Approved and Reason (why not).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The install prompt is written for a person at the console.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Candidate,
        [Parameter()] [ValidateSet('Low', 'Medium', 'High')] [string] $AcceptRisk = 'Low',
        [Parameter()] [switch] $IncludeRecent,
        [Parameter()] [switch] $Force,
        [Parameter()] [switch] $NonInteractive,
        # The pack replaces this version (Update-MtPack): what changed is shown.
        [Parameter()] [AllowNull()] [object] $Previous
    )

    $m = $Candidate.Manifest
    $safe = { param($t, $max = 120) ConvertTo-MtPackSafeText -Text $t -MaxLength $max }
    $riskOrder = @('Low', 'Medium', 'High')
    $console = Get-MtConsoleMode
    $style = { param($text, $s) Format-MtConsoleText $text -Style $s -Console $console }
    $code = & $safe $m.Code 30
    $lines = [System.Collections.Generic.List[string]]::new()
    # One line of the details: a dim label, the value, and lines under it lined up with the value.
    $add = {
        param([string] $label, [string] $value, [string] $valueStyle)
        $shown = if ($valueStyle) { & $style $value $valueStyle } else { $value }
        $lines.Add("    $(& $style $label.PadRight(11) 'Dim') $shown")
    }
    $more = { param([string] $value, [string] $valueStyle) $lines.Add("                $(if ($valueStyle) { & $style $value $valueStyle } else { $value })") }

    $lines.Add('')
    $title = if ($Previous) { 'Update a Maester Pack' } else { 'Install a Maester Pack' }
    $border = switch ($Candidate.Risk) { 'High' { 'Failed' } 'Medium' { 'Error' } default { 'Accent' } }
    foreach ($l in (Format-MtPackPanel -Code $code -Name (& $safe $m.Name 80) -Version (& $safe $m.Version 30) -Id (& $safe $m.Id 60) -Publisher (& $safe $m.Publisher 60) `
                -Description $(if ($m.PSObject.Properties['Description'] -and $m.Description) { & $safe $m.Description 300 } else { '' }) -Title $title -Border $border -Console $console)) { $lines.Add($l) }
    $lines.Add('')
    $sourceLine = switch ($Candidate.Kind) {
        'GitHub' { "github.com/$($Candidate.Owner)/$($Candidate.Repo)$(if ($Candidate.Folder) { "/$($Candidate.Folder)" }) @ $($Candidate.Commit.Substring(0, 7)) ($(if ($Candidate.Ref -eq $Candidate.Commit) { 'commit' } else { "ref $(& $safe $Candidate.Ref 60)" }))" }
        'Local' { "$(& $safe $Candidate.Path 160) (a local folder)" }
        default { 'ships with Maester' }
    }
    & $add 'Source' $sourceLine
    if ($Candidate.Kind -eq 'GitHub' -and $Candidate.Archived) { & $more 'The repository is archived: it is no longer maintained.' 'Error' }
    & $add 'Listing' 'Not listed: not scanned by Maester Packs. The risk below is from the scan on this computer.' 'Dim'
    $connectors = @($m.Connectors | ForEach-Object { "the `"$(& $safe $(if ($_.PSObject.Properties['DisplayName'] -and $_.DisplayName) { $_.DisplayName } else { $_.Service }) 60)`" connector" })
    $adds = @()
    if ($Candidate.TestIds.Count -gt 0) { $adds += "$($Candidate.TestIds.Count) tests (MP.$code.*)" }
    $adds += $connectors
    & $add 'Adds' $(if ($adds) { $adds -join ' and ' } else { 'nothing' })
    foreach ($b in $Candidate.Binaries) {
        & $more "$(& $safe $b.Path 80)  $([math]::Ceiling($b.Size / 1KB)) KB  $($b.Kind)$(if ($b.Signer) { "  signed by $(& $safe $b.Signer 60)" })  sha256 $($b.Sha256.Substring(0, 16))…"
    }
    if ($Previous) {
        $added = @($Candidate.TestIds | Where-Object { $_ -notin @($Previous.Tests) })
        $removed = @(@($Previous.Tests) | Where-Object { $_ -notin $Candidate.TestIds })
        & $add 'Changes' "$($Previous.Version) to $($m.Version); $($added.Count) tests added, $($removed.Count) removed$(if ($removed) { " ($(@($removed | Select-Object -First 5) -join ', ')$(if ($removed.Count -gt 5) { ', …' }))" })"
    }

    # Maester's own lines, last.
    $reach = @($m.Uses.Services) + @($m.Connectors | ForEach-Object { $_.Service }) | Select-Object -Unique
    $hosts = @($m.Uses.Network)
    & $add 'Reaches' $(if ($reach -or $hosts) { (@($reach | ForEach-Object { & $safe $_ 60 }) + @($hosts | ForEach-Object { & $safe $_ 80 })) -join ', ' } else { 'only the services its tests list' })
    $scopes = @($m.Uses.GraphScopes)
    & $add 'Microsoft' $(if ($scopes) { "Graph scopes: $(@($scopes | ForEach-Object { & $safe $_ 80 }) -join ', ')" } else { 'no extra Graph scopes' })
    if (@($m.Uses.TenantWrites).Count -gt 0) { & $more "WRITES TO YOUR TENANT: $(@($m.Uses.TenantWrites | ForEach-Object { & $safe $_ 80 }) -join ', ')" 'Failed' }
    if ($Candidate.Modules.Count -gt 0) {
        $external = @($Candidate.Modules | Where-Object Source -EQ 'External')
        & $add 'Modules' (@($Candidate.Modules | ForEach-Object { "$($_.Name) $($_.Version)$(if ($_.Source -eq 'External') { ' (yours, externally managed)' })" }) -join ', ')
        & $more "each pinned by digest in the lock file$(if ($external) { '; externally managed modules are checked but were not installed by Maester' })" 'Dim'
    }
    $cooldownMet = $true
    if ($Candidate.Kind -eq 'GitHub') {
        $cooldownMet = [bool]$Candidate.CooldownMet
        $age = if ($Candidate.AgeSource -eq 'ImmutableRelease') { "the immutable release $(& $safe $Candidate.Ref 40) was published $($Candidate.AgeHours) hours ago" }
        else { "this computer first saw this content $($Candidate.AgeHours) hours ago; $(if ($Candidate.Release) { 'the release is not immutable, so GitHub''s release date is not used' } else { 'it is not a release' })" }
        if ($cooldownMet) { & $add 'Cooldown' "met: $age" }
        else { & $add 'Cooldown' "NOT MET ($($Candidate.CooldownHours) hours)" 'Error'; & $more $age 'Dim' }
        if ($Candidate.Newer) { & $more "A newer release, $(& $safe $Candidate.Newer.TagName 40), is $($Candidate.Newer.AgeHours) hours old. Use -Version $(& $safe $Candidate.Newer.TagName 40) -IncludeRecent to install it." }
    }
    switch ($Candidate.Risk) {
        'Low' { & $add 'Risk' 'LOW: text files only; no findings from the content checks' 'Passed' }
        'Medium' { & $add 'Risk' 'MEDIUM: findings to read' 'Error' }
        'High' { & $add 'Risk' 'HIGH: install only if you trust the publisher' 'Failed' }
    }
    foreach ($f in ($Candidate.Findings | Sort-Object { $riskOrder.IndexOf($_.Severity) } -Descending | Select-Object -First 12)) {
        & $more "$($f.Severity): $(& $safe $f.Message 160)$(if ($f.File) { " ($(& $safe $f.File 80)$(if ($f.Line) { ":$($f.Line)" }))" })" $(if ($f.Severity -eq 'High') { 'Failed' } elseif ($f.Severity -eq 'Medium') { 'Error' })
    }
    if ($Candidate.Findings.Count -gt 12) { & $more "and $($Candidate.Findings.Count - 12) more; run Test-MtPack to see them all." 'Dim' }
    $lines.Add('')
    $lines.Add((& $style '    This pack runs PowerShell code inside your Maester session, with access to every connection in it,' 'Dim'))
    $lines.Add((& $style '    your environment and your files. Maester checks what it can before it runs, but it is not a sandbox.' 'Dim'))
    $lines.Add('')
    foreach ($line in $lines) { Write-Host $line }

    $needsTypedConfirmation = $Candidate.Risk -eq 'High' -or -not $cooldownMet
    $accepted = $riskOrder.IndexOf($AcceptRisk) -ge $riskOrder.IndexOf($Candidate.Risk)
    if ($NonInteractive) {
        if (-not $accepted) { return [pscustomobject]@{ Approved = $false; Reason = "The pack is $($Candidate.Risk) risk. Without a console, pass -AcceptRisk $($Candidate.Risk) to install it." } }
        if (-not $cooldownMet -and -not $IncludeRecent) { return [pscustomobject]@{ Approved = $false; Reason = "The content is younger than the $($Candidate.CooldownHours)-hour release cooldown. Pass -IncludeRecent to install it anyway." } }
        return [pscustomobject]@{ Approved = $true; Reason = $null }
    }
    if ($needsTypedConfirmation -and -not ($accepted -and ($cooldownMet -or $IncludeRecent) -and $Force)) {
        # The code is what the person sees in the box and in every test ID of the pack.
        $answer = Read-MtPackConfirmation -Prompt "  $(if ($Candidate.Risk -eq 'High') { 'Only install this if you trust the publisher. ' })Type the pack code $(& $style $code 'Accent') to install it"
        if ($answer -ne $code) { return [pscustomobject]@{ Approved = $false; Reason = "The pack was not installed: confirming takes its code, $code$(if ($answer) { ", not '$answer'" })." } }
        return [pscustomobject]@{ Approved = $true; Reason = $null }
    }
    if ($Force) { return [pscustomobject]@{ Approved = $true; Reason = $null } }
    $answer = Read-MtPackConfirmation -Prompt '  Install it? [Y] Yes  [N] No (default is "N")'
    if ($answer -match '^(y|yes)$') { return [pscustomobject]@{ Approved = $true; Reason = $null } }
    [pscustomobject]@{ Approved = $false; Reason = 'The pack was not installed.' }
}

function Read-MtPackConfirmation {
    <#
    .SYNOPSIS
    Reads the answer to a pack prompt from the console.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Prompt)
    (Read-Host -Prompt $Prompt).Trim()
}
