function Test-MtEntraAgentBlueprintCreationRestricted {
    <#
    .SYNOPSIS
    Checks that default users cannot create agent identity blueprints in Microsoft Entra

    .DESCRIPTION
    An agent identity blueprint is the template that agent identities get their credentials from. It is
    an application object made for agents: it holds the credentials, and every agent identity created from
    it authenticates through it. The user who creates a blueprint becomes its owner and can manage its
    credentials and create agent identities from it without holding any Entra role.

    Microsoft is adding a default user role setting, shown in the Entra admin center as "Users can register
    agent identity blueprints" (named "Users can create agent blueprints" in message center item MC1506733),
    which is on by default. From 4 November 2026 (message center item MC1506733) users without a built-in or
    custom Entra role can create blueprints unless an administrator turns the setting off. When it is off,
    only administrators and users with the Agent ID Developer or Agent ID Administrator role can create
    them.

    The setting is stored on the authorization policy as the property
    defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints, which is only returned by the Graph
    beta endpoint and is not yet documented there. The test is skipped when the tenant does not return the
    property, for example before the rollout reaches it.

    .EXAMPLE
    Test-MtEntraAgentBlueprintCreationRestricted

    Returns true if default users are not allowed to create agent identity blueprints

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentBlueprintCreationRestricted
    #>
    [MaesterTest(
        Id = 'MT.1225',
        Title = 'Users should not be able to create Agent Identity Blueprints (Preview).',
        Product = 'entra',
        Feature = 'agent-identities',
        Area = 'ai',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1136.003',
        Control = 'nist-800-53-r5:AC-6',
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'agnivesh'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Checking whether default users can create agent identity blueprints...'
    try {
        $AuthorizationPolicy = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'policies/authorizationPolicy' `
            -Select 'defaultUserRolePermissions' -ErrorAction Stop

        $Permission = $AuthorizationPolicy.defaultUserRolePermissions
        if ($null -eq $Permission -or $null -eq $Permission.allowedToCreateAgentIdentityBlueprints) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                'The tenant does not return the setting "Users can register agent identity blueprints" yet. ' +
                'Microsoft starts the rollout on 4 November 2026.')
            return $null
        }

        $Restricted = $Permission.allowedToCreateAgentIdentityBlueprints -eq $false
        if ($Restricted) {
            $TestResult = 'Well done. Default users cannot create agent blueprints. ' +
                'Only administrators and users with the Agent ID Developer or Agent ID Administrator role can.'
        } else {
            $TestResult = "Default users can create agent blueprints in this tenant.`n`n" +
                'The user who creates a blueprint becomes its owner and can manage its credentials and create ' +
                'agent identities from it without holding an Entra role. Set "Users can register agent identity blueprints" ' +
                'to **No**.'
        }
        Add-MtTestResultDetail -Result $TestResult
        return $Restricted
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
