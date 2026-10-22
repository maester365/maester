function Test-MtCheckEidscaAP15 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create agent identity blueprints is 'false'

    .DESCRIPTION
    Controls whether users can create agent identity blueprints and their associated principals through the default user role. Blueprint creators become owners and can create agent identities for their blueprints. Allowing creation does not itself grant access to organizational data.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints with Test-MtEidscaAP15
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP15',
        Title = 'Default Authorization Settings - Default User Role Permissions - Allowed to create agent identity blueprints.',
        Product = 'entra',
        Feature = 'agent-identities',
        Area = 'ai',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = 'nist-800-53-r5:AC-6(10)',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $AuthorizationPolicyAvailable = (Invoke-MtGraphRequest -RelativeUri 'policies/authorizationpolicy' -ApiVersion beta)
    if ( $null -eq $AuthorizationPolicyAvailable.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'The allowedToCreateAgentIdentityBlueprints setting is not returned by the authorization policy API for this tenant. No compliance conclusion is made when the setting is unavailable.'
        return $null
    }

    $tenantValue = Test-MtEidscaAP15
    return ($tenantValue -eq 'false')
}
