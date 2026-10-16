# Settings registry (Maester 3.0 design, section 7.3). GlobalSettings in the run config may set any key;
# the registry records the type, default and sensitivity of the settings Maester itself reads. Keys that
# are not listed pass through, so test packs can use Namespace.Key. A sensitive setting is redacted in
# the results.
@{
    SchemaVersion = '1.0'
    Settings      = @{
        EmergencyAccessAccounts = @{ Type = 'object[]'; Default = @(); Sensitive = $false; Description = 'Emergency access (break glass) accounts and groups excluded from Conditional Access checks.' }
        DataverseEnvironmentUrl = @{ Type = 'string'; Default = ''; Sensitive = $false; Description = 'URL of the Dataverse environment that the Copilot Studio checks read.' }
        GitHubOrganization      = @{ Type = 'string'; Default = ''; Sensitive = $false; Description = 'GitHub organization that the GitHub checks read.' }
        GitHubApiBaseUri        = @{ Type = 'string'; Default = 'https://api.github.com'; Sensitive = $false; Description = 'Base URI of the GitHub REST API.' }
        GitHubApiVersion        = @{ Type = 'string'; Default = '2022-11-28'; Sensitive = $false; Description = 'GitHub REST API version.' }
    }
}
