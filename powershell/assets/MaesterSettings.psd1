# Settings registry (Maester 3.0 design, section 7.3). It records the type, default and sensitivity of every
# setting Maester itself reads from GlobalSettings in the run config. A pack declares its own settings, named
# Namespace.Key, under Settings in its maester-pack.json; they are added to this registry while the pack runs.
#
# The config is checked against the registry before a run (Test-MtGlobalSetting): a value of the wrong type,
# a value that is not one of AllowedValues or a list item that does not fit Items stops the run, and a key
# without a dot that is not listed here is reported as a likely typo. A Namespace.Key that no pack declares
# passes through, for the settings of custom tests. A sensitive setting is redacted in the results.
#
# Each entry has Type (int, bool, string, string[], object or object[]), Default, Sensitive and Description,
# and may have:
#   Kind           What a string holds, from MaesterParameterKinds.psd1, so a UI can offer a picker.
#   AllowedValues  The values a string or string[] setting accepts.
#   Role           'Connection' for a setting that a connect command or a data helper reads. A test does not
#                  bind it, and the test builder does not offer it.
#   Items          For object[]: Properties (the names an item may have, each with its allowed values or
#                  $null for any) and RequireAny (an item needs at least one of these).
#
# A test never reads a setting itself. It declares a parameter bound to it,
#   [MaesterParameter(Setting = 'ParkedDomains')] [string[]] $ParkedDomains = @()
# and the engine binds the GlobalSettings value when the test's TestSettings row does not set one. The
# parameter's type, default and allowed values must match the entry here, and it takes Kind from here when
# it declares none. A setting holds a fact about the tenant or a choice the organisation makes once (parked
# domains, break-glass accounts), never a value a benchmark sets, which stays a parameter of that test. Name
# a setting after what it holds, never after a test or a suite. A connection or transport setting that a
# connect command or a data helper reads (GitHubOrganization, XspmExternalDataUris) is read with
# Get-MtSetting; the engine records the read on the result of the test that caused it.
@{
    SchemaVersion = '1.0'
    Settings      = @{
        EmergencyAccessAccounts           = @{ Type = 'object[]'; Items = @{ Properties = @{ Id = $null; UserPrincipalName = $null; Type = @('User', 'Group') }; RequireAny = @('Id', 'UserPrincipalName') }; Default = @(); Sensitive = $false; Description = 'Emergency access (break glass) accounts and groups. Checks of Conditional Access, privileged roles and sign-in activity treat them as the exception they are.' }
        ParkedDomains                     = @{ Type = 'string[]'; Kind = 'Entra.Domain'; Default = @(); Sensitive = $false; Description = 'Accepted domains that never send email. The email authentication checks expect them to deny all mail.' }
        DefenderEndpointPolicyFiltering   = @{ Type = 'string'; AllowedValues = @('All', 'IncludeUnassigned', 'OnlyAssigned'); Default = 'OnlyAssigned'; Sensitive = $false; Description = 'Which Defender for Endpoint policies the Defender checks read: All, IncludeUnassigned or OnlyAssigned.' }
        DefenderEndpointComplianceLogic   = @{ Type = 'string'; AllowedValues = @('EffectivePolicy', 'AllPolicies', 'AnyPolicy'); Default = 'EffectivePolicy'; Sensitive = $false; Description = 'How the Defender for Endpoint checks combine policies: EffectivePolicy, AllPolicies or AnyPolicy.' }
        XspmExternalDataUris              = @{ Type = 'object'; Role = 'Connection'; Default = $null; Sensitive = $false; Description = 'HTTPS mirrors of the data sources the XSPM Advanced Hunting queries read: EntraDirectoryRoles, MicrosoftApps, ApiPermissions, ArmApiRequests.' }
        DataverseEnvironmentUrl           = @{ Type = 'string'; Role = 'Connection'; Default = ''; Sensitive = $false; Description = 'URL of the Dataverse environment that the Copilot Studio checks read.' }
        AzureDevOpsOrganization           = @{ Type = 'string'; Role = 'Connection'; Default = ''; Sensitive = $false; Description = 'Azure DevOps organization that Connect-Maester -Service AzureDevOps connects to.' }
        GitHubOrganization                = @{ Type = 'string'; Role = 'Connection'; Default = ''; Sensitive = $false; Description = 'GitHub organization that the GitHub checks read.' }
        GitHubApiBaseUri                  = @{ Type = 'string'; Role = 'Connection'; Default = 'https://api.github.com'; Sensitive = $false; Description = 'Base URI of the GitHub REST API.' }
        GitHubApiVersion                  = @{ Type = 'string'; Role = 'Connection'; Default = '2022-11-28'; Sensitive = $false; Description = 'GitHub REST API version.' }
    }
}
