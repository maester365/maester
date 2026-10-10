function Test-MtCheckEidscaAP08 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - User consent policy assigned for applications is 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

    .DESCRIPTION
    Defines if user consent to apps is allowed, and if it is, which app consent policy (permissionGrantPolicy) governs the permissions.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .permissionGrantPolicyIdsAssignedToDefaultUserRole -clike 'ManagePermissionGrantsForSelf*' with Test-MtEidscaAP08
    and passes when it -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP08',
        Title = 'Default Authorization Settings - User consent policy assigned for applications.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $AuthorizationPolicyAvailable = (Invoke-MtGraphRequest -RelativeUri 'policies/authorizationpolicy' -ApiVersion beta)
    if ( ($AuthorizationPolicyAvailable | where-object permissionGrantPolicyIdsAssignedToDefaultUserRole -Match 'ManagePermissionGrantsForSelf.microsoft-').Count -eq 0 ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'User Consent has been disabled or customized using Microsoft Graph or Microsoft Graph PowerShell without any assignment to custom policy.'
        return $null
    }

    $tenantValue = Test-MtEidscaAP08
    return ($tenantValue -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low')
}
