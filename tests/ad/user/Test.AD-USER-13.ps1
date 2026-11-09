function Test-MtAdUserSidHistoryCount {
    <# .SYNOPSIS
    Checks whether any users retain unapproved migrated SID history.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-13
    Assess user accounts for unapproved migrated SID history.
    .LINK
    https://maester.dev/docs/tests/AD-USER-13
    #>
    [MaesterTest(
        Id = 'AD-USER-13',
        Title = 'Users should not retain unapproved SID history',
        Product = 'ad',
        Feature = 'users',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1134.005',
        Control = 'nist-800-53-r5:AC-2',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Account IDs with approved migration SID history exceptions.
        [string[]] $ApprovedAccountIds = @()
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object { @($_.SIDHistory | Where-Object { $null -ne $_ }).Count -gt 0 -and $ApprovedAccountIds -notcontains $_.SamAccountName -and $ApprovedAccountIds -notcontains $_.DistinguishedName })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) users with unapproved SID history. Validate migration dependencies and approved exceptions; remove history only after access and trust review.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'SIDHistory', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result 'Well done. No unapproved SID history remains on user accounts.' }
    return ($found.Count -eq 0)
}
