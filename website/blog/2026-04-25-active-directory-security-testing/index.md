---
title: "Introducing Active Directory Security Testing in Maester 🏰"
description: Maester now supports comprehensive Active Directory security testing with 300+ new tests covering users, groups, computers, GPOs, DNS, trusts, and more.
slug: active-directory-security-testing
authors: [maesterteam]
tags: [maester, activedirectory, security, ad, release]
hide_table_of_contents: false
date: 2026-04-25
---

# Introducing Active Directory Security Testing in Maester 🏰

We're thrilled to announce a major expansion of Maester's security testing capabilities—**comprehensive Active Directory (AD) security testing** is now available! This release adds **300+ new tests** across 20 categories, giving you unprecedented visibility into your on-premises and hybrid AD infrastructure.

<!-- truncate -->

---

## 🎯 Highlights at a Glance

- **300+ New AD Security Tests** covering every aspect of your directory infrastructure
- **20 Test Categories** from users and groups to DNS, GPOs, and DACL analysis
- **Intelligent Caching** with `Get-MtADDomainState` for efficient data collection
- **Hybrid Ready** - Perfect for organizations with on-premises AD and Entra ID
- **Validated Against Live DCs** - All tests validated on Windows Server 2025 Domain Controllers

---

## Why Active Directory Testing Matters

Active Directory remains the backbone of identity and access management for millions of organizations worldwide. Despite the shift to cloud, **over 90% of Fortune 1000 companies** still rely on AD for authentication and authorization. A compromised AD can lead to:

- Complete domain takeover
- Lateral movement across your network
- Ransomware deployment at scale
- Data exfiltration and theft

Maester's new AD testing capabilities help you identify misconfigurations, security gaps, and compliance issues before attackers do.

---

## 📊 Test Coverage Overview

### Identity & Access Management

| Category | Tests | Description |
|----------|-------|-------------|
| **Users** | 29 | Account status, password policies, delegation, service accounts |
| **Groups** | 22 | Membership, SID history, privileged access, empty groups |
| **Computers** | 10 | Disabled accounts, dormant systems, delegation, SID history |
| **Service Principal Names** | 13 | SPN analysis for Kerberoasting detection |

### Domain Infrastructure

| Category | Tests | Description |
|----------|-------|-------------|
| **Domain & Forest** | 12 | Functional levels, naming, tombstone lifetime, recycle bin |
| **Domain Controllers** | 12 | OS versions, SMB settings, FSMO roles, RODCs, ports |
| **Sites & Subnets** | 16 | Topology, coverage, catch-all subnets, IPv6 |
| **Organizational Units** | 5 | Structure, empty OUs, stale containers |

### Security Configuration

| Category | Tests | Description |
|----------|-------|-------------|
| **Password Policies** | 11 | Default and fine-grained password policies |
| **Group Policy (GPO)** | 11 | GPO inventory, links, enforcement, inheritance |
| **GPO State** | 27 | Detailed GPO analysis, permissions, WMI filters |
| **DACL Analysis** | 18 | Discretionary Access Control List security |
| **Security Accounts** | 13 | KRBTGT, delegation, managed service accounts |

### Network & Integration

| Category | Tests | Description |
|----------|-------|-------------|
| **DNS Infrastructure** | 19 | Zones, records, delegations, DNSSEC, reverse lookup |
| **Trusts** | 7 | Inter-forest trusts, quarantine status, stale trusts |
| **Replication** | 8 | Connection status, optional features, DFS-R |
| **Schema** | 6 | Schema versions, LAPS, modifications |
| **Configuration** | 24 | PKI, LDAP policies, DHCP, CA certificates |

---

## 🔍 Key Test Categories Explained

### User Security Tests

Identify risky user configurations that could lead to compromise:

```powershell
# Run all user security tests
Invoke-Maester -Path "./tests/Maester/ad/user"
```

**Sample Tests:**
- `Test-MtAdUserPasswordNeverExpiresCount` - Find accounts with non-expiring passwords
- `Test-MtAdUserDelegationAllowedCount` - Detect accounts trusted for delegation
- `Test-MtAdUserNoPreAuthCount` - Identify AS-REP Roasting vulnerabilities
- `Test-MtAdUserKerberosDesOnlyCount` - Find legacy DES-only accounts
- `Test-MtAdUserBuiltInAdminEnabledDetails` - Monitor built-in Administrator accounts

### Group Policy Security

Analyze GPO configurations for security issues:

```powershell
# Run GPO security tests
Invoke-Maester -Path "./tests/Maester/ad/gpostate"
```

**Sample Tests:**
- `Test-MtAdGpoCpasswordFoundCount` - Detect encrypted passwords in GPOs
- `Test-MtAdGpoNoAuthenticatedUsersCount` - Find GPOs missing critical permissions
- `Test-MtAdGpoVersionMismatchCount` - Identify AD/Sysvol version mismatches
- `Test-MtAdGpoWmiFilterCount` - Audit WMI filter usage

### DACL Analysis

Deep-dive into Access Control Lists:

```powershell
# Run DACL analysis tests
Invoke-Maester -Path "./tests/Maester/ad/dacl"
```

**Sample Tests:**
- `Test-MtAdDaclPrivilegedAllowAceCount` - Find privileged ACE entries
- `Test-MtAdDaclDenyAceCount` - Audit deny authorization entries
- `Test-MtAdDaclUnresolvedSidCount` - Detect orphaned SIDs in ACLs
- `Test-MtAdDaclConflictObjectCount` - Find conflict objects (CNF)

---

## 🚀 Getting Started

### Prerequisites

- Windows Server with Active Directory role, or domain-joined machine
- PowerShell 5.1 or later
- ActiveDirectory and GroupPolicy PowerShell modules
- Domain Admin or equivalent permissions (for full coverage)

### Installation

```powershell
# Install or update Maester
Install-Module Maester -Scope CurrentUser -Force

# Install Maester tests
md ~/maester-tests
cd ~/maester-tests
Install-MaesterTests
```

### Running AD Tests

```powershell
# Import the Maester module
Import-Module Maester -Force

# Run all AD tests
Invoke-Maester -Path "./tests/Maester/ad" -OutputFolder "./ad-results" -NonInteractive

# Run specific categories
Invoke-Maester -Path "./tests/Maester/ad/user" -OutputFolder "./ad-results" -NonInteractive
Invoke-Maester -Path "./tests/Maester/ad/gpostate" -OutputFolder "./ad-results" -NonInteractive

# Run with specific tags
Invoke-Maester -Tag "AD-User", "AD-Security" -OutputFolder "./ad-results" -NonInteractive
```

### Using the AD Test Runner

For convenience, use the included test runner script:

```powershell
# From the repository root on a domain controller
.\build\activeDirectory\Run-ADTests-And-CopyReports.ps1

# With verbose output
.\build\activeDirectory\Run-ADTests-And-CopyReports.ps1 -Verbose
```

---

## 📈 Understanding Test Results

### Test Output Format

Tests return standardized results:

| Result | Meaning |
|--------|---------|
| `$true` | Test executed successfully / Configuration compliant |
| `$false` | Configuration non-compliant |
| `$null` | AD not available (test skipped) |

### Sample Output

```powershell
# Example: Password Policy Test
Test-MtAdPasswordComplexityRequired
# Returns: $true (complexity enabled - good)

Test-MtAdPasswordMinLength
# Returns: 7 (below recommended 14+)

Test-MtAdAccountLockoutThreshold
# Returns: 0 (disabled - security risk!)
```

### HTML Reports

Generate professional HTML reports for stakeholders:

```powershell
Invoke-Maester -Path "./tests/Maester/ad" -OutputFolder "./reports" -NonInteractive
# Open ./reports/TestResults-*.html
```

---

## 🔐 Security Recommendations

Based on AD test results, consider these best practices:

### Password Policies
- ✅ Set minimum password length to 14+ characters
- ✅ Enable account lockout (threshold ≤ 5 attempts)
- ✅ Configure lockout duration to 30+ minutes
- ✅ Implement fine-grained password policies for privileged accounts

### User Accounts
- ✅ Disable accounts with passwords that never expire
- ✅ Remove delegation from non-DC accounts
- ✅ Eliminate DES-only Kerberos accounts
- ✅ Monitor dormant enabled accounts (>90 days)

### Group Policy
- ✅ Remove cpassword entries from GPOs
- ✅ Ensure all GPOs have Authenticated Users permission
- ✅ Resolve AD/Sysvol version mismatches
- ✅ Audit and remove unlinked GPOs

### Domain Controllers
- ✅ Disable SMBv1 on all DCs
- ✅ Enable SMB signing
- ✅ Use standard LDAP/LDAPS ports (389/636)
- ✅ Keep DC OS versions current

---

## 🔄 Integration with CI/CD

Run AD tests in your automation pipelines:

### GitHub Actions

```yaml
name: AD Security Tests
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  test:
    runs-on: windows-latest
    steps:
      - name: Run Maester AD Tests
        shell: pwsh
        run: |
          Install-Module Maester -Force
          Import-Module Maester
          Invoke-Maester -Path "./tests/Maester/ad" -NonInteractive
```

### Azure DevOps

```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

steps:
- task: PowerShell@2
  inputs:
    targetType: 'inline'
    script: |
      Install-Module Maester -Force
      Import-Module Maester
      Invoke-Maester -Path "./tests/Maester/ad" -OutputFolder "$(Build.ArtifactStagingDirectory)" -NonInteractive
```

---

## 🧪 Test Development & Validation

All 300+ tests were developed following a rigorous 20-phase methodology:

1. **Phase 1-6**: Core objects (Computers, SPNs, Password Policies, DNS, Domain, DCs)
2. **Phase 7-10**: Policy and structure (GPO, Groups, Users, OUs)
3. **Phase 11-14**: Infrastructure (Sites, Trusts, Schema, Config)
4. **Phase 15-20**: Advanced security (DC details, Forest, Security Accounts, Replication, GPO State, DACL)

Each test includes:
- PowerShell test function
- Pester unit tests
- Markdown documentation with security context
- Validation against live Domain Controllers

---

## 📚 Available Commands

### New AD-Specific Cmdlets

| Cmdlet | Description |
|--------|-------------|
| `Get-MtADDomainState` | Collect and cache AD state data |
| `Get-MtADDacls` | Retrieve DACL information |
| `Get-MtADDomainState` | Get domain configuration state |
| `Get-MtADGpoState` | Get GPO detailed state |
| `Clear-MtADCache` | Clear AD cache data |

---

## 🤝 Contributing

Active Directory testing is an ongoing effort. We welcome contributions for:

- New test categories (e.g., Certificate Services, ADFS)
- Additional test cases for existing categories
- Performance optimizations
- Documentation improvements

See our [Contributing Guide](https://maester.dev/docs/contributing) to get started.

---

## 🙏 Thank You

This massive undertaking wouldn't be possible without the Maester community. Special thanks to all contributors who helped design, implement, and validate these 300+ tests.

---

## 🚀 Get Started Today

```powershell
# Update Maester
Update-Module Maester -Force

# Install latest tests
cd ~/maester-tests
Update-MaesterTests

# Run AD tests on your domain controller
Invoke-Maester -Path "./tests/Maester/ad" -NonInteractive
```

---

## 📖 Resources

- [Full AD Test Documentation](https://maester.dev/docs/commands)
- [GitHub Repository](https://github.com/maester365/maester)
- [Join us on Discord](https://discord.gg/maester)
- [Report Issues](https://github.com/maester365/maester/issues)

Happy AD Testing! 🏰🔒
