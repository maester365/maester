- Understanding the distribution of operating systems in your Active Directory environment is crucial for security management. High OS diversity can indicate:

**Security Implications:**
- **Legacy Systems**: Older operating systems may no longer receive security updates
- **Inconsistent Patching**: Different OS versions may have varying patch levels
- **Unsupported Platforms**: End-of-life operating systems pose significant security risks
- **Compliance Issues**: Regulatory requirements may mandate specific OS versions

**Common Scenarios:**
- Windows Server 2008/2012 reaching end-of-life
- Mixed Windows and Linux environments
- Workstations running outdated client OS versions

#### Control Type

**Operational**

#### Security Recommendation

1. **Standardize Operating Systems**:
   - Minimize OS diversity where possible
   - Establish standard builds for servers and workstations
   - Maintain supported OS versions only

2. **Identify End-of-Life Systems**:
   - Create inventory of systems nearing end-of-life
   - Plan upgrade paths for legacy systems
   - Isolate unsupported systems if upgrades are delayed

3. **Patch Management**:
   - Ensure all systems receive regular security updates
   - Prioritize critical and high-severity patches
   - Test patches on representative OS versions

#### How the Test Works

This test analyzes computer objects in Active Directory and:
- Counts distinct operating systems
- Shows distribution percentages
- Identifies computers without OS data

Unknown OS values are counted explicitly; OS service pack and patch state are not available in the current collector. This inventory does not establish deployment or patch health.

#### Related Tests

- **AD-DCOMP-06 — No enabled computers should be stale beyond the configured threshold** — `Test-MtAdComputerStaleEnabledCount` — Reviews enabled-computer staleness.

<!--- Results --->
%TestResult%
