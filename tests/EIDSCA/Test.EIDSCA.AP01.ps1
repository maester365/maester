function Test-MtCheckEidscaAP01 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset for administrators is 'false'

    .DESCRIPTION
    Indicates whether administrators of the tenant can use the Self-Service Password Reset (SSPR). The policy applies to some critical critical roles in Microsoft Entra ID.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .allowedToUseSSPR with Test-MtEidscaAP01
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP01',
        Title = 'Default Authorization Settings - Enabled Self service password reset for administrators.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $AuthorizationPolicyAvailable = (Invoke-MtGraphRequest -RelativeUri 'policies/authorizationpolicy' -ApiVersion beta)
    if ( $AuthorizationPolicyAvailable -notmatch 'allowedToUseSSPR' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Settings value is not available. This may be due to the change that this API is no longer available for recent created tenants or tenants that are not licensed for Entra ID P1.'
        return $null
    }

    $tenantValue = Test-MtEidscaAP01
    return ($tenantValue -eq 'false')
}
