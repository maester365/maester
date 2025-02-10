# Maester Action Script

This PowerShell script is used to monitor your tenant's security configuration using Maester, a PowerShell-based test automation framework.

## Parameters

### Required Parameters

- **TenantId**
  - The Entra Tenant Id.
  - Type: `string`
  - Mandatory: `true`

- **ClientId**
  - The Client Id of the Service Principal.
  - Type: `string`
  - Mandatory: `true`

- **Path**
  - The path for the files and Pester tests.
  - Type: `string`
  - Mandatory: `true`

### Optional Parameters

- **PesterVerbosity**
  - The Pester verbosity level.
  - Type: `string`
  - Mandatory: `false`
  - Default: `None`
  - Allowed Values: `None`, `Normal`, `Detailed`, `Diagnostic`

- **MailUser**
  - The mail user id.
  - Type: `string`
  - Mandatory: `false`
  - Default: `""`

- **MailTo**
  - The mail recipients separated by comma.
  - Type: `string`
  - Mandatory: `false`
  - Default: `""`

- **TestResultURI**
  - The test result URI.
  - Type: `string`
  - Mandatory: `false`
  - Default: `""`

- **IncludeTags**
  - The tags to include in the tests.
  - Type: `string`
  - Mandatory: `false`
  - Default: `""`

- **ExcludeTags**
  - The tags to exclude in the tests.
  - Type: `string`
  - Mandatory: `false`
  - Default: `""`

- **IncludeExchange**
  - Include Exchange Online tests.
  - Type: `bool`
  - Mandatory: `false`
  - Default: `$true`

- **IncludeTeams**
  - Include Teams tests.
  - Type: `bool`
  - Mandatory: `false`
  - Default: `$true`

- **Preview**
  - Install preview version of Maester.
  - Type: `bool`
  - Mandatory: `false`
  - Default: `$false`

- **DisableTelemetry**
  - Disable telemetry.
  - Type: `bool`
  - Mandatory: `false`
  - Default: `$false`

- **GitHubStepSummary**
  - Add test results to GitHub step summary.
  - Type: `bool`
  - Mandatory: `false`
  - Default: `$false`

## Usage

```powershell
.\Run-Maester.ps1 -TenantId "your-tenant-id" -ClientId "your-client-id" -Path "path-to-tests" -PesterVerbosity "Normal" -MailUser "user@example.com" -MailTo "recipient1@example.com,recipient2@example.com" -TestResultURI "http://example.com/results" -IncludeTags "tag1,tag2" -ExcludeTags "tag3" -IncludeExchange $true -IncludeTeams $true -Preview $false -DisableTelemetry $false -GitHubStepSummary $true
```

## Example
```powershell
.\Run-Maester.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ClientId "87654321-4321-4321-4321-210987654321" -Path "./tests" -PesterVerbosity "Detailed" -MailUser "admin@example.com" -MailTo "user1@example.com,user2@example.com" -TestResultURI "http://example.com/results" -IncludeTags "security,compliance" -ExcludeTags "performance" -IncludeExchange $true -IncludeTeams $true -Preview $true -DisableTelemetry $true -GitHubStepSummary $true
```

## Notes

- Ensure you have the necessary permissions and modules installed before running the script.
- The script connects to Microsoft Graph and may require additional authentication steps.
- The script can be customized further by modifying the parameters and their default values.
