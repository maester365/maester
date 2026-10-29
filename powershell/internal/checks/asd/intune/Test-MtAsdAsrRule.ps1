function Test-MtAsdAsrRule {
    <#
    .SYNOPSIS
    Checks that each of the given Microsoft Defender attack surface reduction rules is set to Block by an assigned Intune policy.

    .DESCRIPTION
    Shared by the Essential Eight user application hardening and Microsoft Office macro checks. ASD's assessment
    process guide names the rules each control needs and asks for each to be set to 1 (Block), so Audit, Warn and
    Off are reported and fail: the ISM asks for the behaviour to be blocked, not logged.

    Writes the result detail and returns the result of the check.

    .EXAMPLE
    Test-MtAsdAsrRule -Rule ([ordered]@{ blockofficeapplicationsfrominjectingcodeintootherprocesses = 'Block Office applications from injecting code into other processes' })
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The rules, from the end of each setting definition ID to the name the Intune admin center shows.
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Rule
    )

    $rows = @(Get-MtIntuneAsrRule -Rule @($Rule.Keys))
    $modeRank = @{ Block = 4; Audit = 3; Warn = 2; Off = 1; 'Not configured' = 0 }
    $report = foreach ($name in $Rule.Keys) {
        $settings = @($rows | Where-Object Rule -EQ $name | Sort-Object { $modeRank[$_.Mode] } -Descending)
        $blocking = @($settings | Where-Object { $_.IsAssigned -and $_.Mode -eq 'Block' })
        [pscustomobject]@{
            Name     = $Rule[$name]
            Settings = $settings
            Blocked  = $blocking.Count -gt 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Blocked }).Count -eq 0

    $table = "| Rule | Policy | Mode | Assigned |`n| --- | --- | --- | --- |`n"
    foreach ($r in $report) {
        if ($r.Settings.Count -eq 0) { $table += "| $($r.Name) | None | Not configured | - |`n"; continue }
        foreach ($s in $r.Settings) { $table += "| $($r.Name) | $($s.PolicyName) | $($s.Mode) | $(if ($s.IsAssigned) { 'Yes' } else { 'No' }) |`n" }
    }
    $names = @($Rule.Values | ForEach-Object { "**$_**" }) -join ' and '
    if ($testResult) {
        $testResultMarkdown = "Intune policies with inclusion assignments configure the attack surface reduction rule$(if ($Rule.Count -gt 1) { 's' }) $names to Block.`n`n$table"
    } else {
        $missing = @($report | Where-Object { -not $_.Blocked } | ForEach-Object { "**$($_.Name)**" }) -join ' and '
        $testResultMarkdown = "No assigned Intune policy sets $missing to Block. Audit and Warn only report the behaviour, and a policy that is not assigned applies to no device. Add the rule$(if ($Rule.Count -gt 1) { 's' }) with the mode **Block** to an Endpoint security > Attack surface reduction policy that is assigned to your workstations.`n`n$table"
    }
    $testResultMarkdown += "`n`nThis checks policy configuration and inclusion assignments; it does not verify assignment coverage or exclusions, conflicting policies, or effective settings on devices."
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
