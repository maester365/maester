# Active Directory Test Runner

This folder contains scripts for running Maester Active Directory tests on a domain controller and managing the resulting reports.

## Quick Start

### Option 1: Run All AD Tests (Recommended)

From the repository root on a domain controller:

```powershell
# Run all AD tests and copy reports to build/activeDirectory
.\build\activeDirectory\Run-ADTests-And-CopyReports.ps1

# With verbose output
.\build\activeDirectory\Run-ADTests-And-CopyReports.ps1 -Verbose
```

### Option 2: Run Specific AD Test Categories

```powershell
# Import Maester module first
Import-Module .\powershell\Maester.psd1 -Force

# Run only GPO State tests
Invoke-Maester -Path ".\tests\Maester\ad\gpostate" -OutputFolder ".\build\activeDirectory" -NonInteractive

# Run only Domain tests
Invoke-Maester -Path ".\tests\Maester\ad\domain" -OutputFolder ".\build\activeDirectory" -NonInteractive

# Run only Security tests
Invoke-Maester -Path ".\tests\Maester\ad\security" -OutputFolder ".\build\activeDirectory" -NonInteractive
```

### Option 3: Manual Copy After Running Tests

```powershell
# Run tests with default output
Invoke-Maester -Path ".\tests" -OutputFolder ".\test-results" -NonInteractive

# Copy the latest reports to build/activeDirectory
$latestReports = Get-ChildItem -Path ".\test-results" -Filter "TestResults-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
$latestReports | Copy-Item -Destination ".\build\activeDirectory\" -Force
```

## Available AD Test Categories

The AD tests are organized into the following categories:

| Category | Path | Description |
|----------|------|-------------|
| GPO State | `tests/Maester/ad/gpostate` | GPO configuration and state tests |
| Domain | `tests/Maester/ad/domain` | Domain configuration tests |
| Security | `tests/Maester/ad/security` | Security-related AD tests |
| User | `tests/Maester/ad/user` | User account tests |
| Group | `tests/Maester/ad/group` | Group configuration tests |
| Computer | `tests/Maester/ad/computer` | Computer account tests |
| GPO | `tests/Maester/ad/gpo` | Group Policy Object tests |
| Password Policy | `tests/Maester/ad/passwordpolicy` | Password policy tests |
| Replication | `tests/Maester/ad/replication` | AD replication tests |
| DACL | `tests/Maester/ad/dacl` | Discretionary Access Control List tests |
| Domain Controller | `tests/Maester/ad/domaincontroller` | DC-specific tests |
| DNS | `tests/ad/dns` | DNS-related tests |
| OU | `tests/ad/ou` | Organizational Unit tests |
| Site | `tests/ad/site` | AD site topology tests |
| Schema | `tests/ad/schema` | AD schema tests |
| SPN | `tests/ad/spn` | Service Principal Name tests |
| Trust | `tests/ad/trust` | Domain trust tests |
| Config | `tests/ad/config` | General configuration tests |

## Script Parameters

### Run-ADTests-And-CopyReports.ps1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MaesterModulePath` | `..\..\powershell` | Path to Maester PowerShell module |
| `TestPath` | `..\..\tests` | Path to test files |
| `OutputFolder` | `..\..\test-results` | Temporary output folder |
| `TargetFolder` | Current folder | Where to copy final reports |

## Report Files

After running tests, the following files are generated:

- **HTML Report** (`AD-TestResults-*.html`) - Interactive web-based report
- **Markdown Report** (`AD-TestResults-*.md`) - Markdown format for documentation
- **JSON Data** (`AD-TestResults-*.json`) - Raw test data for automation
- **CSV Export** (optional) - Spreadsheet format
- **Excel Export** (optional) - Excel workbook format

## Requirements

- Windows Server with Active Directory role (or domain-joined machine)
- PowerShell 5.1 or later
- ActiveDirectory PowerShell module
- GroupPolicy PowerShell module
- Domain Admin or equivalent permissions (for full test coverage)

## Troubleshooting

### "Access Denied" Errors
- Ensure you're running PowerShell as Administrator
- Verify you have Domain Admin or equivalent permissions
- Check that the ActiveDirectory and GroupPolicy modules are installed

### "Module Not Found" Errors
- Verify the Maester module path is correct
- Run `Import-Module .\powershell\Maester.psd1 -Force` to test module import

### Tests Taking Too Long
- Use `-Path` parameter to run specific test categories
- Exclude long-running tests with appropriate tags
- Run tests during off-peak hours

### No Reports Generated
- Check the output folder path exists and is writable
- Verify Invoke-Maester completed successfully
- Look for error messages in the console output

## Examples

### Example 1: Full AD Test Suite
```powershell
.\build\activeDirectory\Run-ADTests-And-CopyReports.ps1 -Verbose
```

### Example 2: Quick GPO Validation Only
```powershell
Import-Module .\powershell\Maester.psd1 -Force
Invoke-Maester -Path ".\tests\Maester\ad\gpostate" -OutputFolder ".\build\activeDirectory" -NonInteractive
```

### Example 3: Export to CSV and Excel
```powershell
Invoke-Maester -Path ".\tests\Maester\ad" -OutputFolder ".\build\activeDirectory" -ExportCsv -ExportExcel -NonInteractive
```

### Example 4: Run with Specific Tags
```powershell
Invoke-Maester -Path ".\tests\Maester\ad" -Tag "AD-GPOS" -OutputFolder ".\build\activeDirectory" -NonInteractive
```

## See Also

- [Phase 19 Validation Guide](Phase19-Validation-README.md) - GPO State validation
- [Maester Documentation](https://maester.dev) - Full Maester documentation
- [AD Test Backlog](ADTestBacklog.md) - AD test development status
