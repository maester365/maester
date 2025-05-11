#region Test-AzdoAllowRequestAccessToken

function Test-AzdoAllowRequestAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $UserPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $UserPolicies.policy | where-object -property name -eq 'Policy.AllowRequestAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "When enabled, this policy allows users to request access, triggering email notifications to administrators for review and approval."
    }
    else {
        $resultMarkdown = "Well done. Disabling the policy stops these requests and notifications."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description" -Description "$Description"

    return $result
}
#endregion Test-AzdoAllowRequestAccessToken

#region Test-AzdoAllowTeamAdminsInvitationsAccessToken

function Test-AzdoAllowTeamAdminsInvitationsAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowTeamAdminsInvitationsAccessToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Team and project administrators is allowed to invite new users"
    }
    else {
        $resultMarkdown = "Well done. Enrolling to your Azure DevOps organization should be a controlled process."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description" -Description "$Description"

    return $result
}
#endregion Test-AzdoAllowTeamAdminsInvitationsAccessToken

#region Test-AzdoArtifactsExternalPackageProtectionToken

function Test-AzdoArtifactsExternalPackageProtectionToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.ArtifactsExternalPackageProtectionToken'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your Azure DevOps tenant limits access to externally sourced packages when internally sources packages are already present."
    }
    else {
        $resultMarkdown = "Your tenant should prefer to use internal source packages when present"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoArtifactsExternalPackageProtectionToken

#region Test-AzdoAuditStreams

function Test-AzdoAuditStreams {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $AuditStreams = Get-ADOPSAuditStreams
    
    if ($AuditStreams) {
        if ('Enabled' -in $AuditStreams.status) {
            $resultMarkdown = "Well done. Audit logs have been configured for long-term storage and purge protection."
            $result = $true
        }
        else {
            $resultMarkdown = "Audit Streams have been configured for long-term storage and purge protection but is not enabled."
            $result = $false
        }
    }
    else {
        $resultMarkdown = "Audit Streams have not been configured for long-term storage and purge protection."
        $result = $false
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoAuditStreams

#region Test-AzdoEnforceAADConditionalAccess

function Test-AzdoEnforceAADConditionalAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.EnforceAADConditionalAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators."
    }
    else {
        $resultMarkdown = "Your tenant should always perform validation for any Conditional Access Policies (CAPs) set by tenant administrators. "
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoEnforceAADConditionalAccess

#region Test-AzdoExternalGuestAccess

function Test-AzdoExternalGuestAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.DisallowAadGuestUserAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "External user(s) can be added to the organization to which they were invited and has immediate access. A guest user can add other guest users to the organization after being granted the Guest Inviter role in Microsoft Entra ID."
    }
    else {
        $resultMarkdown = "Well done. External users should not be allowed access to your Azure DevOps organization"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoExternalGuestAccess

#region Test-AzdoFeedbackCollection

function Test-AzdoFeedbackCollection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Privacy'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.AllowFeedbackCollection'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your Azure DevOps tenant allows feedback collection."
    }
    else {
        $resultMarkdown = "You should have confidence that we're handling your data appropriately and for legitimate uses. Part of that assurance involves carefully restricting usage."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoFeedbackCollection

#region Test-AzdoLogAuditEvents

function Test-AzdoLogAuditEvents {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.LogAuditEvents'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has auditing enabled, tracking events such as permission changes, deleted resources, log access and downloads with many other types of changes."
    }
    else {
        $resultMarkdown = "Your tenant do not have logging enabled for Azure DevOps"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoLogAuditEvents

#region Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProjects

function Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProjects {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationAdvancedSecurity).enableOnCreate

    if ($result) {
        $resultMarkdown = "Well done. New projects will by default have Advanced Security enabled."
    }
    else {
        $resultMarkdown = "New projects must be manually enrolled in Advanced Security."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProjects

#region Test-AzdoOrganizationBadgesArePrivate

function Test-AzdoOrganizationBadgesArePrivate {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).statusBadgesArePrivate

    if ($result) {
        $resultMarkdown = "Well done. Azure DevOps badges are private."
    }
    else {
        $resultMarkdown = "Anonymous users can access the status badge API for all pipelines."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationBadgesArePrivate

#region Test-AzdoOrganizationCreationClassicBuildPipelines

function Test-AzdoOrganizationCreationClassicBuildPipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PipelineCreation = (Get-ADOPSOrganizationPipelineSettings).disableClassicBuildPipelineCreation

    if ($PipelineCreation) {
        $resultMarkdown = "Well done. No classic build pipelines can be created / imported. Existing ones will continue to work."
        $result = $false
    }
    else {
        $resultMarkdown = "Classic build pipelines can be created / imported."
        $result = $true
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationCreationClassicBuildPipelines

#region Test-AzdoOrganizationCreationClassicReleasePipelines

function Test-AzdoOrganizationCreationClassicReleasePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PipelineCreation = (Get-ADOPSOrganizationPipelineSettings).disableClassicReleasePipelineCreation

    if ($PipelineCreation) {
        $resultMarkdown = "Well done. No classic release pipelines, task groups, and deployment groups can be created / imported. Existing ones will continue to work."
        $result = $false
    }
    else {
        $resultMarkdown = "Classic release pipelines, task groups, and deployment groups can be created / imported."
        $result = $true
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationCreationClassicReleasePipelines

#region Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipelines

function Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceJobAuthScope

    if ($result) {
        $resultMarkdown = "Well done. Access tokens have reduced scope of access for all non-release pipelines."
    }
    else {
        $resultMarkdown = "Non-Release Pipelines can run with collection scoped access tokens"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipelines

#region Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipelines

function Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipelines {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceJobAuthScopeForReleases

    if ($result) {
        $resultMarkdown = "Well done. Access tokens have reduced scope of access for all classic release pipelines."
    }
    else {
        $resultMarkdown = "Classic Release Pipelines can run with collection scoped access tokens"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipelines

#region Test-AzdoOrganizationLimitVariablesAtQueueTime

function Test-AzdoOrganizationLimitVariablesAtQueueTime {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceSettableVar

    if ($result) {
        $resultMarkdown = "Well done. With this option enabled, only those variables that are explicitly marked as ""Settable at queue time"" can be set"
    }
    else {
        $auditEnforceSettableVar = (Get-ADOPSOrganizationPipelineSettings).auditEnforceSettableVar
        if ($auditEnforceSettableVar) {
            $resultMarkdown = "Auditing is configured, however usage is not restricted."
        }
        else {
            $resultMarkdown = "Users can define new variables not defined by pipeline author, and may override system variables."
        }
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationLimitVariablesAtQueueTime

#region Test-AzdoOrganizationOwner

function Test-AzdoOrganizationOwner {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw
    
    $Data = Get-ADOPSOrganizationAdminOverview
    if ($data.'ms.vss-admin-web.organization-admin-overview-delay-load-data-provider'.exceptionType -eq 'AadGraphException') {
        $resultMarkdown = "Workload identities cannot fetch Organization Owner."
        Add-MtTestResultDetail -Result "BUG: Workload identities cannot fetch Organization Owner." -SkippedCustomReason "Workload identities cannot fetch Organization Owner." -SkippedBecause Custom -Description "$Description"
        $result = $false
    }
    else {
        $currentOwner = $data.'ms.vss-admin-web.organization-admin-overview-delay-load-data-provider'.currentOwner
        if ($currentOwner.email -match '(?i)(adm|admin|btg|svc|service)') {
            $resultMarkdown = "Well done. Azure DevOps organization owner should be a service account and not an individual."
            $result = $true
        }
        else {
            $resultMarkdown = "Azure DevOps organization owner should not be an individual ($($currentOwner.name)). Note: This might be a false positive."
            $result = $false
        }
        Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"
    }
    return $result
}
#endregion Test-AzdoOrganizationOwner

#region Test-AzdoOrganizationProtectAccessToRepositories

function Test-AzdoOrganizationProtectAccessToRepositories {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceReferencedRepoScopedToken

    if ($result) {
        $resultMarkdown = "Well done. Checks and approvals are applied when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline."
    }
    else {
        $resultMarkdown = "Checks and approvals are not applied when accessing repositories from YAML pipelines. Also, a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline is not generated."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationProtectAccessToRepositories

#region Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepos

function Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepos {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationRepositorySettings | Where-object key -eq "DisableTfvcRepositories").value

    if ($result) {
        $resultMarkdown = "Well done. Team Foundation Version Control (TFVC) repositories cannot be created."
    }
    else {
        $resultMarkdown = "Team Foundation Version Control (TFVC) can be created."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepos

#region Test-AzdoOrganizationRepositorySettingsGravatarImages

function Test-AzdoOrganizationRepositorySettingsGravatarImages {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationRepositorySettings | Where-object key -eq "GravatarEnabled").value

    if ($result) {
        $resultMarkdown = "Gravatar images are exposed for users outside of your enterprise."
    }
    else {
        $resultMarkdown = "Well done. Gravatar images are not exposed outside of your enterprise."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationRepositorySettingsGravatarImages

#region Test-AzdoOrganizationStageChooser

function Test-AzdoOrganizationStageChooser {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $StageChooser = (Get-ADOPSOrganizationPipelineSettings).disableStageChooser

    if ($result) {
        $resultMarkdown = "Well done. Users will not be able to select stages to skip from the Queue Pipeline panel."
        $result = $false
    }
    else {
        $resultMarkdown = "Users are able to select stages to skip from the Queue Pipeline panel."
        $result = $true
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationStageChooser

#region Test-AzdoOrganizationStorageUsage

function Test-AzdoOrganizationStorageUsage {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $StorageUsage = Get-ADOPSOrganizationCommerceMeterUsage -MeterId '3efc2e47-d73e-4213-8368-3a8723ceb1cc'
    $availableQuantity = $StorageUsage.availableQuantity

    if ($availableQuantity -lt [double]::Parse('0,1')) {
        $resultMarkdown = "Your storage is exceeding the usage limit or close to. '$availableQuantity' GB available."
        $result = $false
    }
    else {
        $resultMarkdown = 
        @'
        Well done. You are not exceeding or approaching your storage usage limit.
        Current usage: {0} GB
        Max quantity: {1} GB
'@ -f $StorageUsage.currentQuantity, $StorageUsage.maxQuantity
        $result = $true
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationStorageUsage

#region Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTasks

function Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTasks {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableMarketplaceTasksVar

    if ($result) {
        $resultMarkdown = "It is allowed to install and run tasks from the Marketplace."
    }
    else {
        $resultMarkdown = "Well done. The ability to install and run tasks from the Marketplace has been restricted."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTasks

#region Test-AzdoOrganizationTaskRestrictionsDisableNode6Tasks

function Test-AzdoOrganizationTaskRestrictionsDisableNode6Tasks {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableNode6TasksVar

    if ($result) {
        $resultMarkdown = "Well done. Pipelines will fail if they utilize a task with a Node 6 execution handler."
    }
    else {
        $resultMarkdown = "Pipeliens may utilize a task with Node 6 execution handler."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationTaskRestrictionsDisableNode6Tasks

#region Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation

function Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enableShellTasksArgsSanitizing

    if ($result) {
        $resultMarkdown = "Well done. Argument parameters for built-in shell tasks are validated to check for inputs that can inject commands into scripts."
    }
    else {
        $resultMarkdown = "Argument parameters for built-in shell tasks may inject commands into scripts."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation

#region Test-AzdoOrganizationTriggerPullRequestGitHubRepositories

function Test-AzdoOrganizationTriggerPullRequestGitHubRepositories {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings
    $result = $settings.forkProtectionEnabled

    if ($result) {
        if ($settings.requireCommentsForNonTeamMemberAndNonContributors) {
            $AdditionalInfo = 'Only on pull requests from non-team members and contributors'
        }
        elseif ($settings.requireCommentsForNonTeamMembersOnly) {
            $AdditionalInfo = 'Only on pull requests from non-team members'
        }
        else {
            $AdditionalInfo = 'On all pull requests'
        }
        
        $data = @'
            Prevent pipelines from making secrets available to fork builds is set to '{0}'\
            Prevent pipelines from making fork builds have the same permissions as regular builds is set to '{1}'\
            Require a team member's comment before building a pull request is set to '{2}' ({3})
'@ -f $settings.enforceNoAccessToSecretsFromForks, $settings.enforceJobAuthScopeForForks, $settings.isCommentRequiredForPullRequest, $AdditionalInfo

        $resultMarkdown = "Well done. You have configured building pull requests from forked GitHub repositories according to your requirements. $data"
    }
    else {
        $resultMarkdown = "No limits building pull requests from forked GitHub repositories have been configured."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoOrganizationTriggerPullRequestGitHubRepositories

#region Test-AzdoProjectCollectionAdministrators

function Test-AzdoProjectCollectionAdministrators {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    function Get-NestedAdoMembership {
        param (
            [Parameter()]
            $Member
        )

        if ($Member.subjectKind -eq 'group') {
            Write-Verbose "Finding members in group '$($Member.DisplayName)' - Descriptor '$($_.Descriptor)'"
            Get-ADOPSMembership -Descriptor $Member.descriptor -Direction 'down' | Foreach-object {
                Write-Verbose "Processing member '$($_.DisplayName)' - Descriptor '$($_.Descriptor)'"
                Get-NestedAdoMembership -Member $_
            }
        }
        else {
            Write-output $Member
        }
    }

    $PCA = Get-ADOPSGroup | Where-object -Property displayname -eq 'Project Collection Administrators'
    $PCAMembers = Get-ADOPSMembership -Descriptor $PCA.descriptor -Direction 'down'

    # UniqueUserList
    $UniqueUsersWithPCA = New-Object System.Collections.Arraylist

    # Users with PCA
    $UserPCA = $PCAMembers | Where-Object { $_.subjectKind -ne 'group' }
    $UserPCA | Foreach-object {
        $UniqueUsersWithPCA.Add($_) | Out-Null
    }

    # Groups with PCA
    $GroupPCA = $PCAMembers | Where-Object { $_.subjectKind -eq 'group' }

    $GroupPCA | Foreach-object {
        Get-NestedAdoMembership -Member $_ | Foreach-object {
            if ($_.descriptor -notin $UniqueUsersWithPCA.descriptor) {
                $UniqueUsersWithPCA.Add($_) | Out-Null
            }
            else {
                Write-Verbose "$($_.subjectKind) - $($_.displayname) - $($_.descriptor) - has already been added."
            }
        }

    }

    if ($UniqueUsersWithPCA.Count -ge 4) {
        $result = $false
        $resultMarkdown = "Restrict direct user access (Current actively assigned users/service accounts; '$($UniqueUsersWithPCA.Count)') to Project Collection Administrators role. The role holds the highest authority within an organization or project collection. Members can Perform all operations for the entire collection, Manage settings, policies, and processes for the organization, create and manage all projects and extensions."
    }
    else {
        $result = $true
        $resultMarkdown = "Well done. Less than 4 users/service accounts are directly assigned to the Project Collection Administrators role."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoProjectCollectionAdministrators

#region Test-AzdoPublicProjects

function Test-AzdoPublicProjects {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.AllowAnonymousAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant allows the creation and use of public projects"
    }
    else {
        $resultMarkdown = "Well done. Your tenant has disabled the use of public projects"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoPublicProjects

#region Test-AzdoResourceUsageProjects

function Test-AzdoResourceUsageProjects {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Projects = (Get-ADOPSResourceUsage).Projects

    $CurrentUsage = $($Projects.count / $Projects.limit).Tostring("P")

    if ($($Projects.count / $Projects.limit) -gt 0.9) {
        $resultMarkdown = "Project Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    }
    else {
        $resultMarkdown = "Well done. Project Resource Usage limit is at $CurrentUsage"
        $result = $true
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoResourceUsageProjects

#region Test-AzdoResourceUsageWorkItemTags

function Test-AzdoResourceUsageWorkItemTags {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $WorkItemTags = (Get-ADOPSResourceUsage).'Work Item Tags'

    $CurrentUsage = $($WorkItemTags.count / $WorkItemTags.limit).Tostring("P")

    if ($($WorkItemTags.count / $WorkItemTags.limit) -gt 0.9) {
        $resultMarkdown = "Work Item Tags Resource Usage limit is greater than 90% - Current usage: $CurrentUsage"
        $result = $false
    }
    else {
        $resultMarkdown = "Well done. Work Item Tags Resource Usage limit is at $CurrentUsage"
        $result = $true
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoResourceUsageWorkItemTags

#region Test-AzdoSSHAuthentication

function Test-AzdoSSHAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection'
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowSecureShell'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant allows developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }
    else {
        $resultMarkdown = "Well done. Your tenant do not allow developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoSSHAuthentication

#region Test-AzdoThirdPartyAccessViaOauth

function Test-AzdoThirdPartyAccessViaOauth {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection'
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowOAuthAuthentication'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant have not restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    }
    else {
        $resultMarkdown = "Well done. Your tenant has restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    }

    $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown -Description "$Description"

    return $result
}
#endregion Test-AzdoThirdPartyAccessViaOauth

