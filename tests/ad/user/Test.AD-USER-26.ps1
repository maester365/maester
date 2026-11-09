function Test-MtAdUserHoneyPotCount {
    <# .SYNOPSIS
    Inventories explicitly configured decoy account IDs for review.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-26
    Review configured decoy account IDs manually; absent configuration may be skipped.
    .LINK
    https://maester.dev/docs/tests/AD-USER-26
    #>
    [MaesterTest(
        Id = 'AD-USER-26',
        Title = 'Configured decoy users should be reviewed',
        Product = 'ad',
        Feature = 'users',
        Area = 'logging-and-detection',
        ResourceType = 'User',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Explicit decoy SIDs, distinguished names or sAMAccountNames; names alone never imply decoys.
        [string[]] $AccountIds = @()
    )

    if (-not $AccountIds.Count) { Add-MtTestResultDetail -SkippedBecause NotApplicable; return $false }
    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object { $AccountIds -contains $_.SamAccountName -or $AccountIds -contains $_.DistinguishedName -or $AccountIds -contains [string]$_.SID -or $AccountIds -contains [string]$_.SID.Value })
    foreach ($id in $AccountIds) {
        if (-not @($found | Where-Object { $id -eq $_.SamAccountName -or $id -eq $_.DistinguishedName -or $id -eq [string]$_.SID -or $id -eq [string]$_.SID.Value }).Count) { throw "Configured decoy account not found: $id" }
    }
    Add-MtTestResultDetail -Result "Review $($found.Count) explicitly configured decoy identities and confirm monitoring/ownership. Account names alone were not used as evidence.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Enabled', 'LastLogonDate', 'DistinguishedName'))" -Investigate
    return $true
}
