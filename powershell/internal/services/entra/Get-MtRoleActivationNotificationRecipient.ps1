function Get-MtRoleActivationNotificationRecipient {
    <#
    .SYNOPSIS
        Returns the additional recipients of the role activation alert of a directory role.

    .DESCRIPTION
        Privileged Identity Management sends a "Role activation alert" to the administrators when an eligible member
        activates a role. Its additional recipients are stored in the role's management policy, in the rule
        Notification_Admin_EndUser_Assignment (notificationRecipients). Returns those addresses, or nothing when the
        role sends the alert to no additional recipient.

    .EXAMPLE
        Get-MtRoleActivationNotificationRecipient -RoleDefinitionId '62e90394-69f5-4237-9190-012177145e10'

        Returns the additional recipients of the activation alert of the Global Administrator role.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        # The ID of the directory role definition.
        [Parameter(Mandatory)]
        [string] $RoleDefinitionId
    )

    $policySplat = @{
        ApiVersion      = 'v1.0'
        RelativeUri     = 'policies/roleManagementPolicyAssignments'
        Filter          = "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$RoleDefinitionId'"
        QueryParameters = @{ expand = 'policy(expand=rules)' }
    }
    $assignment = Invoke-MtGraphRequest @policySplat
    $rule = @($assignment.policy.rules) | Where-Object { $_.id -eq 'Notification_Admin_EndUser_Assignment' } | Select-Object -First 1
    return [string[]]@($rule.notificationRecipients | Where-Object { $_ })
}
