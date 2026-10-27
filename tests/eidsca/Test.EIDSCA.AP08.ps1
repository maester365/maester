function Test-MtCheckEidscaAP08 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - User consent assignments match the restricted or Microsoft recommended baseline is '0'

    .DESCRIPTION
    Counts user consent assignments outside microsoft-user-default-low and microsoft-user-default-recommended. Either accepted policy or both passes. An explicit empty assignment collection or only resource-specific consent assignments passes because no default ManagePermissionGrantsForSelf policy is assigned. Missing or null assignment data is skipped. The legacy unrestricted policy fails, including when mixed with other policies. Other user consent policies, including custom policies and mail-client exceptions, require manual review and are skipped unless the legacy policy is also assigned. A pass confirms assignment compliance only; this check does not evaluate policy conditions, other consent authorization mechanisms, or existing grants.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .permissionGrantPolicyIdsAssignedToDefaultUserRole with Test-MtEidscaAP08
    and passes when it -eq '0'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP08',
        Title = 'Default Authorization Settings - User consent assignments match the restricted or Microsoft recommended baseline.',
        Product = 'entra',
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1528', 'T1566.002'),
        Control = ('nist-800-53-r5:AC-6(10)', 'nist-800-53-r5:CM-5'),
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $AuthorizationPolicyAvailable = (Invoke-MtGraphRequest -RelativeUri 'policies/authorizationpolicy' -ApiVersion beta)
    if ( $null -eq $AuthorizationPolicyAvailable.permissionGrantPolicyIdsAssignedToDefaultUserRole -or ((($AuthorizationPolicyAvailable.permissionGrantPolicyIdsAssignedToDefaultUserRole -match '^ManagePermissionGrantsForSelf\.') -notmatch '^ManagePermissionGrantsForSelf\.microsoft-user-default-(low|recommended|legacy)$').Count -gt 0 -and $AuthorizationPolicyAvailable.permissionGrantPolicyIdsAssignedToDefaultUserRole -notcontains 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy') ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Manual review required: consent policy assignments are unavailable, or user consent policies other than microsoft-user-default-low and microsoft-user-default-recommended require evaluation of their includes and excludes against the organization''s baseline. This includes custom policies and microsoft-user-default-allow-consent-apps mail-client exceptions. No compliance conclusion is made for these policies.'
        return $null
    }

    $tenantValue = Test-MtEidscaAP08
    return ($tenantValue -eq '0')
}
