Describe "Azure DevOps" -Tag "Azure DevOps" {
    It "AZDO.1000: Azure DevOps OAuth apps can access resources in your organization through OAuth. See https://aka.ms/vstspolicyoauth" -Tag "AZDO.1000" {

        Test-AzdoThirdPartyAccessViaOauth | Should -Be $false -Because "Your tenant should restrict Azure DevOps OAuth apps to access resources in your organization through OAuth."

    }

    It "AZDO.1001: Identities can connect to your organization's Git repos through SSH. See https://aka.ms/vstspolicyssh" -Tag "AZDO.1001" {

        Test-AzdoSSHAuthentication | Should -Be $false -Because "Authentication towards your tenant should only be by Entra, do not allow developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }

    It "AZDO.1002: Log Audit Events. See https://aka.ms/log-audit-events" -Tag "AZDO.1002" {

        Test-AzdoLogAuditEvent | Should -Be $true -Because "Auditing should be enabled for Azure DevOps"
    }

    It "AZDO.1003: Restrict public projects. See https://aka.ms/vsts-anon-access" -Tag "AZDO.1003" {

        Test-AzdoPublicProject | Should -Be $false -Because "Public projects should be disabled for Azure DevOps"
    }

    It "AZDO.1004: Additional protections when using public package registries. See https://aka.ms/upstreamBehaviorBlog" -Tag "AZDO.1004" {

        Test-AzdoArtifactsExternalPackageProtectionToken | Should -Be $true -Because "Limiting access to externally sourced packages when internally sources packages are already present in Azure DevOps"
    }

    It "AZDO.1005: IP Conditional Access policy validation. See https://aka.ms/visual-studio-conditional-access-policy" -Tag "AZDO.1005" {

        Test-AzdoEnforceAADConditionalAccess | Should -Be $true -Because "Microsoft Entra ID should always perform validation for any Conditional Access Policies (CAPs) set by tenant administrators."
    }

    It "AZDO.1006: External Users access. See https://aka.ms/vstspolicyguest" -Tag "AZDO.1006" {

        Test-AzdoExternalGuestAccess | Should -Be $false -Because "External users should not be allowed access to your Azure DevOps organization"
    }

    It "AZDO.1007: Team and project administrator are allowed to invite new users. See https://aka.ms/azure-devops-invitations-policy" -Tag "AZDO.1007" {

        Test-AzdoAllowTeamAdminsInvitationsAccessToken | Should -Be $false -Because "Enrolling to your Azure DevOps organization should be a controlled process."
    }

    It "AZDO.1008: Request access to Azure DevOps by e-mail notifications to administrators. See https://go.microsoft.com/fwlink/?linkid=2113172" -Tag "AZDO.1008" {

        Test-AzdoAllowRequestAccessToken | Should -Be $false -Because "You should prevent users from requesting access to your organization or projects"
    }

    It "AZDO.1009: Feedback Collection. See https://aka.ms/ADOPrivacyPolicy" -Tag "AZDO.1009" {

        Test-AzdoFeedbackCollection | Should -Be $true -Because "You should have confidence that we're handling your data appropriately and for legitimate uses. Part of that assurance involves carefully restricting usage."
    }

    It "AZDO.1010: Audit streaming. See https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops" -Tag "AZDO.1010" {

        Test-AzdoAuditStream | Should -Be $true -Because "Setting up a stream also allows you to store more than 90-days worth of auditing data."
    }

    It "AZDO.1011: Project Resource Limits. See https://learn.microsoft.com/en-us/azure/devops/organizations/projects/about-projects?view=azure-devops" -Tag "AZDO.1011" {

        Test-AzdoResourceUsageProject | Should -Be $true -Because "Azure DevOps supports up to 1,000 projects within an organization."
    }

    It "AZDO.1012: Work Items Tags Limits. See https://learn.microsoft.com/en-us/azure/devops/organizations/settings/work/object-limits?view=azure-devops" -Tag "AZDO.1012" {

        Test-AzdoResourceUsageWorkItemTag | Should -Be $true -Because "Azure DevOps supports up to 150,000 tag definitions per organization or collection."
    }

    It "AZDO.1013: Organization Owner should not be an individual. See https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-organization-ownership?view=azure-devops" -Tag "AZDO.1013" {

        Test-AzdoOrganizationOwner | Should -Be $true -Because "Organization owners are automatically members of the 'Project Collection Administrators' group. As roles and responsibilities change, you can change the owner for your organization."
    }

    It "AZDO.1014: Anonymous access to pipeline badges. See https://learn.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=net%2Cbrowser#add-a-status-badge-to-your-repository" -Tag "AZDO.1014" {

        Test-AzdoOrganizationBadgesArePrivate | Should -Be $true -Because "Even in a private project, anonymous badge access is enabled by default. With anonymous badge access enabled, users outside your organization might be able to query information such as project names, branch names, job names, and build status through the badge status API."
    }

    It "AZDO.1015: Limit variables that can be set at queue time. See https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#limit-variables-that-can-be-set-at-queue-time" -Tag "AZDO.1015" {

        Test-AzdoOrganizationLimitVariablesAtQueueTime | Should -Be $true -Because "Only those variables explicitly marked as 'Settable at queue time' can be set. In other words, you can set any variables at queue time unless this setting is turned on."
    }

    It "AZDO.1016: Limit job authorization scope to current project for non-release pipelines. See https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope" -Tag "AZDO.1016" {

        Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline  | Should -Be $true -Because "With this option enabled, you can reduce the scope of access for all classic release pipelines to the current project."
    }

    It "AZDO.1017: Limit job authorization scope to current project for classic release pipelines. See https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope" -Tag "AZDO.1017" {

        Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipeline | Should -Be $true -Because "With this option enabled, you can reduce the scope of access for all non-release pipelines to the current project."
    }

    It "AZDO.1018: Protect access to repositories in YAML pipelines. See https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#restrict-project-repository-and-service-connection-access" -Tag "AZDO.1018" {

        Test-AzdoOrganizationProtectAccessToRepository | Should -Be $true -Because "Apply checks and approvals when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline."
    }

    It "AZDO.1019: Stage chooser. See https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops" -Tag "AZDO.1019" {

        Test-AzdoOrganizationStageChooser | Should -Be $false -Because "Users should not be able to select stages to skip from the Queue Pipeline panel"
    }

    It "AZDO.1020: Creation of classic build pipelines. See https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/" -Tag "AZDO.1020" {

        Test-AzdoOrganizationCreationClassicBuildPipeline | Should -Be $false -Because "Creating classic build pipelines should not be allowed."
    }

    It "AZDO.1021: Creation of classic release pipelines. See https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines/" -Tag "AZDO.1021" {

        Test-AzdoOrganizationCreationClassicReleasePipeline | Should -Be $false -Because "Creating classic release pipelines should not be allowed."
    }

    It "AZDO.1022: Limit building pull requests from forked GitHub repositories. See https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops&tabs=yaml#validate-contributions-from-forks" -Tag "AZDO.1022" {

        Test-AzdoOrganizationTriggerPullRequestGitHubRepository | Should -Be $true -Because "Azure Pipelines can automatically build and validate every pull request and commit to your GitHub repository. This should be configured according to your organizations requirements."
    }

    It "AZDO.1023: Disable Marketplace tasks. See https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution" -Tag "AZDO.1023" {

        Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTask | Should -Be $true -Because "Disable the ability to install and run tasks from the Marketplace, which gives you greater control over the code that executes in a pipeline."
    }

    It "AZDO.1024: Disable Node 6 tasks. See https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2022/no-node-6-on-hosted-agents" -Tag "AZDO.1024" {

        Test-AzdoOrganizationTaskRestrictionsDisableNode6Task | Should -Be $true -Because "With this enabled, pipelines will fail if they utilize a task with a Node 6 execution handler."
    }

    It "AZDO.1025: Enable shell tasks arguments validation. See https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs?view=azure-devops#shellTasksValidation" -Tag "AZDO.1025" {

        Test-AzdoOrganizationTaskRestrictionsShellTaskArgumentValidation | Should -Be $true -Because "When this is enabled, argument parameters for built-in shell tasks are validated to check for inputs that can inject commands into scripts."
    }

    It "AZDO.1026: Enable automatic enrollment to Advanced Security for Azure DevOps. See https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml#organization-level-onboarding" -Tag "AZDO.1026" {

        Test-AzdoOrganizationAutomaticEnrollmentAdvancedSecurityNewProject | Should -Be $true -Because "Enable automatic enrollment for new git repositories to use GitHub Advanced Security for Azure DevOps. It adds GitHub Advanced Security's suite of security features to Azure Repos."
    }

    It "AZDO.1027: Disable showing Gravatar images for users outside of your enterprise. See https://learn.microsoft.com/en-us/azure/devops/repos/git/repository-settings?view=azure-devops&tabs=browser#gravatar-images" -Tag "AZDO.1027" {

        Test-AzdoOrganizationRepositorySettingsGravatarImage | Should -Be $false -Because "Gravatar images should not be exposed outside of your enterprise."
    }

    It "AZDO.1028: Disable creation of TFVC repositories. See https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2024/no-tfvc-in-new-projects" -Tag "AZDO.1028" {

        Test-AzdoOrganizationRepositorySettingsDisableCreationTFVCRepo | Should -Be $true -Because "Team Foundation Version Control (TFVC) has been deprecated."
    }

    It "AZDO.1029: Storage Usage Limit. See https://learn.microsoft.com/en-us/azure/devops/artifacts/reference/limits?view=azure-devops" -Tag "AZDO.1029" {

        Test-AzdoOrganizationStorageUsage | Should -Be $true -Because "Storage Usage Limit should not be reached."
    }

    It "AZDO.1030: Project Collection Administrators. See https://learn.microsoft.com/en-us/azure/devops/organizations/security/about-permissions?view=azure-devops&tabs=preview-page#permissions" -Tag "AZDO.1030" {

        Test-AzdoProjectCollectionAdministrator | Should -Be $true -Because "Users should not be directly assigned to 'Project Collection Administrator' as it is the most privileged role within Azure DevOps."
    }

}


