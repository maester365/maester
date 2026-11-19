function Test-MtAdGpoSettingsDisabledCount {
    <#
    .SYNOPSIS
    Inventories disabled user, computer or both GPO settings.
    .DESCRIPTION
    Combines category counts and policy details. Numeric and named statuses are
    matched exactly; unknown statuses remain visible and never count as enabled.
    #>
    [MaesterTest(
        Id = 'AD-GPOS-04', Title = 'Disabled GPO settings should be investigated',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'GroupPolicy', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOs) { throw 'GPO metadata could not be collected; disabled settings cannot be inventoried.' }
    $rows = @(foreach ($gpo in @($state.GPOs | Where-Object { $null -ne $_ })) {
            $status = switch -Regex (([string]$gpo.GpoStatus).Trim()) {
                '^(0|AllDisabled|AllSettingsDisabled)$' { 'All settings disabled'; break }
                '^(1|UserDisabled|UserSettingsDisabled)$' { 'User settings disabled'; break }
                '^(2|ComputerDisabled|ComputerSettingsDisabled)$' { 'Computer settings disabled'; break }
                '^(3|AllEnabled|AllSettingsEnabled)$' { 'All settings enabled'; break }
                default { 'Unknown' }
            }
            [pscustomobject]@{ Name = $gpo.DisplayName; Id = $gpo.Id; Status = $status }
        })
    $disabled = @($rows | Where-Object { $_.Status -notin 'All settings enabled', 'Unknown' })
    $unknown = @($rows | Where-Object Status -EQ 'Unknown')
    $summary = if ($disabled.Count -eq 0 -and $unknown.Count -eq 0) { 'No collected GPO has disabled user or computer settings.' }
    elseif ($unknown.Count -eq $rows.Count) { 'Settings status could not be determined for any collected GPO.' }
    elseif ($disabled.Count -eq 0) { 'No disabled settings were found among evaluated GPOs.' }
    else { "$($disabled.Count) of $($rows.Count) GPOs have disabled settings. Review whether each disabled category is intentional." }
    if ($unknown.Count -gt 0) { $summary += " Settings status is unknown for $($unknown.Count) GPOs." }
    $metrics = [ordered]@{
        'Total GPOs' = $rows.Count
        'GPOs with disabled settings' = $disabled.Count
        'Only user settings disabled' = @($rows | Where-Object Status -EQ 'User settings disabled').Count
        'Only computer settings disabled' = @($rows | Where-Object Status -EQ 'Computer settings disabled').Count
        'All settings disabled' = @($rows | Where-Object Status -EQ 'All settings disabled').Count
        'GPOs with unknown status' = $unknown.Count
    }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics $metrics -Details @($disabled + $unknown | Sort-Object Name) -Properties Name, Id, Status -Headers GPO, Id, 'Settings status'
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
