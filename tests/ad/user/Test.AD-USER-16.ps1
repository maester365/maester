function Test-MtAdUserHomeDirectoryCount {
    <# .SYNOPSIS
    Checks user home, profile and logon-script paths against approved roots.
    #>
    [MaesterTest(
        Id = 'AD-USER-16',
        Title = 'User home, profile and script paths should be approved',
        Product = 'ad',
        Feature = 'users',
        Area = 'access-control',
        ResourceType = 'User',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1037.003',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Case-insensitive approved UNC or absolute path roots; empty means no absolute paths approved.
        [string[]] $ApprovedPathPrefixes = @()
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @(Get-MtAdUserPathFindings -Users @($state.Users) -ApprovedPathPrefixes $ApprovedPathPrefixes)
    $failed = @($found | Where-Object { $_.Finding -ne 'Relative NETLOGON script: review (not failed)' })
    $review = @($found | Where-Object { $_.Finding -eq 'Relative NETLOGON script: review (not failed)' })
    $table = Format-MtAdUserSecurityTable $found @('SamAccountName', 'Field', 'Path', 'Finding')
    if ($failed.Count) { Add-MtTestResultDetail -Result "Found $($failed.Count) unapproved or traversal paths; $($review.Count) relative NETLOGON scripts require review. Approve trusted roots or correct affected account paths. Path approval does not verify share or file ACLs.`n`n$table" }
    elseif ($review.Count) { Add-MtTestResultDetail -Result "Relative NETLOGON scripts for $($review.Count) users need a manual review; no unapproved absolute paths were found. ACL security has not been assessed.`n`n$table" -Investigate }
    else { Add-MtTestResultDetail -Result 'Well done. No unapproved home, profile or absolute logon-script paths were found. File and share ACLs are not assessed.' }
    return ($failed.Count -eq 0)
}
