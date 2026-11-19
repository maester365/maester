function Test-MtAdGpoCpasswordFoundCount {
    <#
    .SYNOPSIS
    Checks for exposed secrets in Group Policy files.
    .DESCRIPTION
    Flags either Group Policy Preferences cpassword or default passwords, including cases with only one finding type. Never includes credential values.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-17', Title = 'No GPO should expose cpassword or default passwords',
        Product = 'ad', Feature = 'group-policy', Area = 'authentication',
        ResourceType = 'GroupPolicy', Severity = 'Critical', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = ('T1552.001', 'T1552.006'),
        Control = ('nist-800-53-r5:IA-5(1)', 'nist-800-53-r5:SC-28'),
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports -or $null -eq $state.GPOs) {
        throw 'GPO secret scan reports or GPO metadata could not be collected.'
    }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    if ($reports.Count -eq 0 -or $reports.Count -ne @($state.GPOs).Count) { throw 'GPO secret scan reports are empty or do not match the GPO inventory.' }
    $incomplete = @($reports | Where-Object {
            $null -eq $_.CpasswordFound -or $null -eq $_.DefaultPasswordFound -or
            $null -eq $_.Errors -or @($_.Errors).Count -gt 0
        })
    $cpassword = @($reports | Where-Object { $true -eq $_.CpasswordFound })
    $defaultPassword = @($reports | Where-Object { $true -eq $_.DefaultPasswordFound })
    $found = @($reports | Where-Object { $true -eq $_.CpasswordFound -or $true -eq $_.DefaultPasswordFound })
    if ($found.Count -eq 0 -and $incomplete.Count -gt 0) {
        throw "SYSVOL secret scan incomplete for $($incomplete.Count) GPOs; check access and scan errors before claiming no exposed passwords."
    }
    $pass = $found.Count -eq 0
    $message = if ($pass) { "Well done. No cpassword or default password found in $($reports.Count) scanned GPOs." }
    else { "$($found.Count) of $($reports.Count) GPOs expose passwords ($($cpassword.Count) with cpassword, $($defaultPassword.Count) with default passwords). Remove the secrets and rotate affected credentials." }
    if ($incomplete.Count -gt 0) { $message += " Scanning was incomplete for $($incomplete.Count) GPOs." }
    $result = Format-MtAdGpoResult -Summary $message -Metrics ([ordered]@{ 'Total GPOs' = $reports.Count; 'GPOs exposing passwords' = $found.Count; 'GPOs with cpassword' = $cpassword.Count; 'GPOs with default passwords' = $defaultPassword.Count; 'GPOs with incomplete scans' = $incomplete.Count }) -Details @($found | Sort-Object Name) -Properties Name, CpasswordFound, DefaultPasswordFound -Headers GPO, 'cpassword present', 'Default password present'
    Add-MtTestResultDetail -Result $result
    return $pass
}
