function Test-MtDisaRoleActivationNotification {
    <#
    .SYNOPSIS
    Checks that every directory role with an active or eligible assignment sends its activation alert to additional recipients.

    .DESCRIPTION
    The DISA Microsoft Entra ID STIG (V-270255) asks that system administrators and the information system security
    officer (ISSO) are notified when privileges are requested. Its check opens the Privileged Identity Management
    settings of each Microsoft Entra role that has an active or eligible assignment and verifies that the SA and
    ISSO addresses are listed under "Additional recipients" of the "Role activation alert".

    This check lists the roles with an active or eligible assignment and reads the additional recipients of each
    role's activation alert. A role fails when it has none or, when RequiredRecipients is set, when one of those
    addresses is missing.

    CISA.MS.AAD.7.8 and CISA.MS.AAD.7.9 read the same alert, but only for the roles that CISA counts as highly
    privileged, so this is a test of its own.

    .EXAMPLE
    Test-MtDisaRoleActivationNotification

    Returns true when every assigned role sends its activation alert to at least one additional recipient.

    .EXAMPLE
    Test-MtDisaRoleActivationNotification -RequiredRecipients 'sa@contoso.mil', 'isso@contoso.mil'

    Returns true when every assigned role sends its activation alert to both addresses.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270255
    #>
    [MaesterTest(
        Id = 'DISA.V-270255',
        Title = 'Microsoft Entra ID must notify system administrators (SAs) and the information system security officer (ISSO) when privileges are being requested.',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1098.003', 'T1548.005'),
        Control = 'disa-stig-entra-id:V-270255',
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Email addresses that every role's activation alert must be sent to, such as the SA and the ISSO. Empty accepts any additional recipient.
        [string[]] $RequiredRecipients
    )

    $assignments = @((Get-MtDirectoryRoleAssignment).Assignments | Where-Object { $_ })
    $roleIds = @($assignments.roleDefinitionId | Where-Object { $_ } | Sort-Object -Unique)
    if ($roleIds.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }
    $names = @{}
    foreach ($definition in @(Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -Select id, displayName)) {
        $names[$definition.id] = $definition.displayName
    }

    $rows = foreach ($roleId in $roleIds) {
        $recipients = @(Get-MtRoleActivationNotificationRecipient -RoleDefinitionId $roleId)
        $missing = if ($RequiredRecipients) {
            @($RequiredRecipients | Where-Object { $_ -notin $recipients })
        } elseif ($recipients.Count -eq 0) {
            @('an additional recipient')
        } else {
            @()
        }
        [pscustomobject]@{
            Role       = if ($names.ContainsKey($roleId)) { $names[$roleId] } else { $roleId }
            Recipients = $recipients
            Missing    = $missing
        }
    }
    $rows = @($rows | Sort-Object Role)
    $failing = @($rows | Where-Object { $_.Missing.Count -gt 0 })
    $testResult = $failing.Count -eq 0

    $link = 'https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles'
    $table = "| Role | Additional recipients of the activation alert | Result |`n| --- | --- | --- |`n"
    foreach ($row in $rows) {
        $value = if ($row.Recipients.Count -gt 0) { Get-MtSafeMarkdown ($row.Recipients -join ', ') } else { 'None' }
        $result = if ($row.Missing.Count -gt 0) { "❌ Missing $(Get-MtSafeMarkdown ($row.Missing -join ', '))" } else { '✅ Pass' }
        $table += "| $(Get-MtSafeMarkdown $row.Role) | $value | $result |`n"
    }
    if ($testResult) {
        $testResultMarkdown = "Well done. Every role with an active or eligible assignment sends its [activation alert]($link) to the required recipients.`n`n$table"
    } else {
        $testResultMarkdown = "$($failing.Count) of $($rows.Count) role(s) with an active or eligible assignment do not send their [activation alert]($link) to the required recipients.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
