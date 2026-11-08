function Test-MtAdGpoCpasswordFoundCount {
    <#
    .SYNOPSIS
    Checks for exposed secrets in Group Policy files.
    .DESCRIPTION
    Flags either Group Policy Preferences cpassword or security-template default passwords, including cases with only one finding type. Never includes credential values.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-17',
        Title = 'No GPO should expose cpassword or default passwords',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'authentication',
        ResourceType = 'GroupPolicy',
        Severity = 'Critical',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1552.001', 'T1552.006'),
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
    if ($incomplete.Count -gt 0) {
        throw "SYSVOL secret scan incomplete for $($incomplete.Count) GPOs; check access and scan errors before claiming no exposed passwords."
    }
    $cpassword = @($reports | Where-Object { $true -eq $_.CpasswordFound })
    $defaultPassword = @($reports | Where-Object { $true -eq $_.DefaultPasswordFound })
    $found = @($reports | Where-Object { $true -eq $_.CpasswordFound -or $true -eq $_.DefaultPasswordFound })
    $table = "| GPO | cpassword present | Default password present |`n| --- | --- | --- |`n"
    foreach ($report in @($found | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $table += "| $name | $([bool]$report.CpasswordFound) | $([bool]$report.DefaultPasswordFound) |`n"
    }
    $pass = $found.Count -eq 0
    $message = if ($pass) { "Well done. No cpassword or default password found in $($reports.Count) scanned GPOs." }
    else { "$($found.Count) of $($reports.Count) GPOs expose passwords ($($cpassword.Count) with cpassword, $($defaultPassword.Count) with default passwords). Remove the secrets and rotate the affected credentials." }
    Add-MtTestResultDetail -Result "$message`n`n$table"
    return $pass
}
