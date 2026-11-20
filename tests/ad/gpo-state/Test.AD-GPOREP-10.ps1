function Test-MtAdGpoNoApplyGroupPolicyAceCount {
    <#
    .SYNOPSIS
    Checks that every GPO has an explicit Apply Group Policy allow entry.

    .DESCRIPTION
    Fails when a GPO has no explicit application entry and lists affected policies.
    This does not calculate effective access for every target principal.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOREP-10'

    Fails when a GPO has no explicit Apply Group Policy allow entry.

    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-10
    #>
    [MaesterTest(
        Id                 = 'AD-GPOREP-10',
        Title              = 'GPOs should have an Apply Group Policy allow entry',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'access-control',
        ResourceType       = 'GroupPolicy',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Platform           = 'Windows',
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports) { throw 'GPO permission reports could not be collected.' }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    if ($reports.Count -eq 0) { throw 'No GPO permission reports were collected.' }
    $missing = @($reports | Where-Object { $false -eq $_.HasApplyGroupPolicyAce })
    $unknown = @($reports | Where-Object { $null -eq $_.HasApplyGroupPolicyAce })
    if ($unknown.Count -gt 0) { throw 'GPO application permissions could not be evaluated for every policy.' }
    $details = @($missing | Sort-Object Name | ForEach-Object { [pscustomobject]@{ Name = $_.Name; ApplicationEntry = 'Not present' } })
    $message = if ($missing.Count -eq 0) { "Well done. All $($reports.Count) GPOs have an Apply Group Policy allow entry." }
    else { "Grant appropriate application rights or archive intentionally unused policies: $($missing.Count) of $($reports.Count) GPOs have no Apply Group Policy allow entry." }
    $result = Format-MtAdGpoResult -Summary $message -Metrics ([ordered]@{ 'Total GPOs' = $reports.Count; 'GPOs without Apply Group Policy entries' = $missing.Count }) -Details $details -Properties Name, ApplicationEntry -Headers GPO, 'Apply Group Policy entry'
    Add-MtTestResultDetail -Result $result
    return ($missing.Count -eq 0)
}
