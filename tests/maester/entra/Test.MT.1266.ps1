function Test-MtEntraIDConnectSyncAccidentalDeletionPrevention {
    <#
    .SYNOPSIS
    Checks if accidental deletion prevention is enabled for on-premises directory synchronization

    .DESCRIPTION
    Microsoft Entra Connect Sync stops an export to Microsoft Entra ID when it would delete more objects than the
    tenant's accidental deletion threshold. A filtering change, a renamed OU or an attacker with control of the
    on-premises directory can otherwise delete a large number of cloud users and groups in one sync cycle.

    The threshold is stored in the tenant, and changing it needs a Microsoft Entra credential, so control of the
    on-premises directory alone is not enough to turn it off.

    .EXAMPLE
    Test-MtEntraIDConnectSyncAccidentalDeletionPrevention

    Returns true if accidental deletion prevention is enabled for the tenant

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraIDConnectSyncAccidentalDeletionPrevention
    #>
    [MaesterTest(
        Id                 = 'MT.1266',
        Title              = 'Accidental deletion prevention should be enabled for directory synchronization.',
        Product            = 'entra',
        Feature            = 'hybrid-identity',
        Area               = 'infrastructure',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = ('T1485', 'T1531'),
        Service            = 'Graph',
        Permission         = 'Graph:DelegatedScope:OnPremDirectorySynchronization.Read.All',
        Author             = 'I3iker'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # The API supports delegated permissions only.
    if ((Get-MgContext).AuthType -ne 'Delegated') {
        Add-MtTestResultDetail -SkippedBecause NotSupportedAppPermission
        return $null
    }

    $organization = Invoke-MtGraphRequest -RelativeUri 'organization'
    if ($organization.onPremisesSyncEnabled -ne $true) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    try {
        $synchronization = @(Invoke-MtGraphRequest -RelativeUri 'directory/onPremisesSynchronization' -ApiVersion v1.0 -ErrorAction Stop)
    } catch {
        # Global Administrator is the only role that can read this API.
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $prevention = $synchronization[0].configuration.accidentalDeletionPrevention
    $type = $prevention.synchronizationPreventionType
    $threshold = $prevention.alertThreshold

    if ($type -eq 'enabledForCount') {
        Add-MtTestResultDetail -Result "Well done. Accidental deletion prevention is enabled. An export that deletes more than **$threshold** objects is stopped."
        return $true
    }
    if ($type -eq 'enabledForPercentage') {
        Add-MtTestResultDetail -Result "Well done. Accidental deletion prevention is enabled. An export that deletes more than **$threshold %** of the synchronized objects is stopped."
        return $true
    }

    $state = if ($type) { "**$type**" } else { 'not set' }
    $testResult = "Accidental deletion prevention is $state for this tenant.`n`n" `
        + 'A single on-premises change, such as a filtering change or a renamed OU, can delete any number of synchronized users and groups in Microsoft Entra ID. ' `
        + 'Enable it with a threshold that fits the size of your directory.'
    Add-MtTestResultDetail -Result $testResult
    return $false
}
