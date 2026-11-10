# Settings registry (Maester 3.0 design, section 7.3). GlobalSettings in the run config may set any key;
# the registry records the type, default and sensitivity of the settings Maester itself reads. Keys that
# are not listed pass through, so test packs can use Namespace.Key. A sensitive setting is redacted in
# the results.
#
# A test never reads a setting itself. It declares a parameter bound to it,
#   [MaesterParameter(Setting = 'ParkedDomains')] [string[]] $ParkedDomains = @()
# and the engine binds the GlobalSettings value when the test's TestSettings row does not set one. The
# parameter's type must match Type here, and it takes Kind from here when it declares none. A setting holds
# a fact about the tenant or a choice the organisation makes once (parked domains, break-glass accounts),
# never a value a benchmark sets, which stays a parameter of that test. Name a setting after what it holds,
# never after a test or a suite.
@{
    SchemaVersion = '1.0'
    Settings      = @{
        EmergencyAccessAccounts           = @{ Type = 'object[]'; Default = @(); Sensitive = $false; Description = 'Emergency access (break glass) accounts and groups excluded from Conditional Access checks.' }
        ParkedDomains                     = @{ Type = 'string[]'; Kind = 'Entra.Domain'; Default = @(); Sensitive = $false; Description = 'Accepted domains that never send email. The email authentication checks expect them to deny all mail.' }
        DefenderEndpointPolicyFiltering   = @{ Type = 'string'; Default = 'OnlyAssigned'; Sensitive = $false; Description = 'Which Defender for Endpoint policies the Defender checks read: All, IncludeUnassigned or OnlyAssigned.' }
        DefenderEndpointComplianceLogic   = @{ Type = 'string'; Default = 'EffectivePolicy'; Sensitive = $false; Description = 'How the Defender for Endpoint checks combine policies: EffectivePolicy, AllPolicies or AnyPolicy.' }
        DataverseEnvironmentUrl           = @{ Type = 'string'; Default = ''; Sensitive = $false; Description = 'URL of the Dataverse environment that the Copilot Studio checks read.' }
        AzureDevOpsOrganization           = @{ Type = 'string'; Default = ''; Sensitive = $false; Description = 'Azure DevOps organization that Connect-Maester -Service AzureDevOps connects to.' }
        GitHubOrganization                = @{ Type = 'string'; Default = ''; Sensitive = $false; Description = 'GitHub organization that the GitHub checks read.' }
        GitHubApiBaseUri                  = @{ Type = 'string'; Default = 'https://api.github.com'; Sensitive = $false; Description = 'Base URI of the GitHub REST API.' }
        GitHubApiVersion                  = @{ Type = 'string'; Default = '2022-11-28'; Sensitive = $false; Description = 'GitHub REST API version.' }
    }
}
