# Active Directory Test Implementation Backlog

## Overview

This document contains the comprehensive backlog of all Active Directory security tests derived from `Get-Analysis.ps1`. The tests are organized into logical phases to enable collaborative implementation across multiple sessions.

## Test Naming Convention

- **Test Function**: `Test-MtAd<Category><TestName>`
  - Example: `Test-MtAdComputerDisabledCount`, `Test-MtAdPasswordPolicyHistory`
- **Pester Test File**: `Test-MtAd<TestName>.Tests.ps1`
  - Example: `Test-MtAdComputerDisabledCount.Tests.ps1`
- **Markdown Doc**: `<TestName>.md`
  - Example: `Test-MtAdComputerDisabledCount.md`

## Implementation Status Legend

- 🔴 **Not Started**: Test has not been implemented
- 🟡 **In Progress**: Test implementation is underway
- 🟢 **Complete**: Test is fully implemented and tested
- ⚫ **Blocked**: Test is blocked by dependencies or unclear requirements

---

## Implementation Learnings & Patterns

### Documentation Standards (Updated)

Based on Phase 1 implementation, documentation should follow these guidelines:

1. **Location**: Documentation files (`.md`) must be placed in the **same directory** as the PowerShell function, not in `website/docs/commands/`

2. **Content Focus**: Documentation should focus on **WHY the test matters** from a security perspective:
   - What security risks does this test identify?
   - Why is this configuration important?
   - What are the recommended remediation steps?
   - How does this relate to compliance frameworks?

3. **Structure**: Each documentation file should include:
   - `# FunctionName` - Title
   - `## Why This Test Matters` - Security value proposition
   - `## Security Recommendation` - Actionable guidance
   - `## How the Test Works` - Technical implementation overview
   - `## Related Tests` - Links to complementary tests

### Data Source Patterns

Tests use the `Get-MtADDomainState` cache mechanism:
```powershell
$adState = Get-MtADDomainState
if ($null -eq $adState) {
    Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
    return $null
}
$computers = $adState.Computers
```

### Return Value Convention

- Return `$null` when AD is not available (test is skipped)
- Return `$true` when data is successfully retrieved (informational tests)
- Return `$true`/`$false` for compliance tests based on security criteria

### Key Properties Available

Computer objects from the cache include these key properties:
- `Enabled` - Account status
- `lastLogonDate` - Last authentication timestamp
- `DistinguishedName` - Full LDAP path
- `primaryGroupId` - Primary group (515, 516, 521 are standard)
- `SIDHistory` - Migration SIDs
- `TrustedForDelegation` - Unconstrained delegation flag
- `TrustedToAuthForDelegation` - Constrained delegation flag

---

## Phase 1: Computer Objects (AdRecon - Computers.csv)

**Phase Goal**: Implement tests for computer object security analysis
**Estimated Tests**: 10
**Dependencies**: None

**Status**: 🟢 Complete
**Completed By**: Session-A (Sisyphus)
**Completed Date**: 2026-04-25
**Tests Completed**: 10/10

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-COMP-01 | ComputerDisabledCount | Count of disabled computer objects | Returns count of disabled/total computers | 🟢 | Session-A |
| AD-COMP-02 | ComputerDormantCount | Count of dormant (>90 days) computers | Returns count of dormant/total computers | 🟢 | Session-A |
| AD-COMP-03 | ComputerCreatorSidCount | Computers with ms-ds-CreatorSid attribute | Returns count of computers with CreatorSid | 🟢 | Session-A |
| AD-COMP-04 | ComputerNonStandardGroup | Computers with non-standard Primary Group ID | Returns count of computers not in groups 515,516,521 | 🟢 | Session-A |
| AD-COMP-05 | ComputerSidHistoryCount | Computers with SID History set | Returns count of computers with SID History | 🟢 | Session-A |
| AD-COMP-06 | ComputerInDefaultContainer | Computers in default Computers container | Returns count of computers in CN=Computers | 🟢 | Session-A |
| AD-COMP-07 | ComputerOUCount | Distinct OUs containing computer objects | Returns count of unique OUs with computers | 🟢 | Session-A |
| AD-COMP-08 | ComputerPerOUAverage | Average computers per container | Returns average count per distinct container | 🟢 | Session-A |
| AD-COMP-09 | ComputerDelegationCount | Computers with delegations configured | Returns count of computers with delegation settings | 🟢 | Session-A |
| AD-COMP-10 | ComputerDelegationDetails | Detailed delegation configuration | Returns breakdown of delegation types per computer | 🟢 | Session-A |

---

## Phase 2: Service Principal Names (AdRecon - ComputerSPNs.csv & UserSPNs.csv)

**Phase Goal**: Implement tests for SPN security analysis
**Estimated Tests**: 13
**Dependencies**: None

**Status**: 🟢 Complete
**Completed By**: Session-B (Sisyphus)
**Completed Date**: 2026-04-25
**Tests Completed**: 13/13

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-SPN-01 | ComputerSpnServiceClassCount | Distinct SPN service classes in use | Returns count of unique SPN service classes | 🟢 | Session-B |
| AD-SPN-02 | ComputerSpnServiceClassUsage | SPN service class usage breakdown | Returns list of service classes with counts | 🟢 | Session-B |
| AD-SPN-03 | ComputerSpnUnknownCount | Unidentified SPN service classes | Returns count of unknown SPN types | 🟢 | Session-B |
| AD-SPN-04 | ComputerSpnUnknownDetails | Details of unidentified SPNs | Returns list of unknown SPNs with counts | 🟢 | Session-B |
| AD-SPN-05 | ComputerSpnNonFqdnHosts | SPN hosts without FQDN | Returns count of hosts without FQDN | 🟢 | Session-B |
| AD-SPN-06 | UserSpnTotalCount | Total user SPNs in use | Returns count of user SPNs | 🟢 | Session-B |
| AD-SPN-07 | UserSpnServiceClassCount | Distinct user SPN service classes | Returns count of unique user SPN classes | 🟢 | Session-B |
| AD-SPN-08 | UserSpnServiceClassUsage | User SPN service class breakdown | Returns list of user SPN classes with counts | 🟢 | Session-B |
| AD-SPN-09 | UserSpnUnknownCount | Unidentified user SPN classes | Returns count of unknown user SPN types | 🟢 | Session-B |
| AD-SPN-10 | UserSpnUnknownDetails | Details of unidentified user SPNs | Returns list of unknown user SPNs with counts | 🟢 | Session-B |
| AD-SPN-11 | UserSpnNonFqdnHosts | User SPN hosts without FQDN | Returns count of user SPN hosts without FQDN | 🟢 | Session-B |
| AD-SPN-12 | UserSpnDomainAdminCount | SPNs associated with Domain Admin | Returns count of SPNs on domain admin account | 🟢 | Session-B |
| AD-SPN-13 | UserSpnDomainAdminDetails | Domain Admin SPN details | Returns list of SPNs on domain admin account | 🟢 | Session-B |

---

## Phase 3: Password Policies (AdRecon - DefaultPasswordPolicy.csv & FineGrainedPasswordPolicy.csv)

**Phase Goal**: Implement tests for password policy security analysis
**Estimated Tests**: 11
**Dependencies**: None

**Status**: 🟢 Complete (Validated)
**Completed By**: Session-C (Sisyphus)
**Completed Date**: 2026-04-25
**Validated Date**: 2026-04-25
**Tests Completed**: 11/11
**Validated Against Live DC**: ✅ Yes

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-PWDPOL-01 | PasswordHistoryCount | Password history enforcement count | Returns number of passwords remembered | 🟢 | Session-C |
| AD-PWDPOL-02 | PasswordMaxAge | Maximum password age in days | Returns max password age (recommend: 90 days or less) | 🟢 | Session-C |
| AD-PWDPOL-03 | PasswordMinLength | Minimum password length | Returns min length (recommend: 14+ characters) | 🟢 | Session-C |
| AD-PWDPOL-04 | PasswordComplexityRequired | Password complexity requirement status | Returns whether complexity is enabled (should be true) | 🟢 | Session-C |
| AD-PWDPOL-05 | PasswordReversibleEncryption | Reversible encryption status | Returns whether reversible encryption is used (should be false) | 🟢 | Session-C |
| AD-PWDPOL-06 | AccountLockoutDuration | Account lockout duration in minutes | Returns lockout duration (recommend: 30+ minutes) | 🟢 | Session-C |
| AD-PWDPOL-07 | AccountLockoutThreshold | Account lockout threshold | Returns failed attempts before lockout (recommend: 5 or less) | 🟢 | Session-C |
| AD-FGPP-01 | FineGrainedPolicyCount | Count of fine-grained password policies | Returns number of FGPPs configured | 🟢 | Session-C |
| AD-FGPP-02 | FineGrainedPolicyValueCount | Distinct values per FGPP | Returns count of distinct values across policies | 🟢 | Session-C |
| AD-FGPP-03 | FineGrainedPolicySettingCounts | Settings distribution across policies | Returns breakdown of settings per policy | 🟢 | Session-C |
| AD-FGPP-04 | FineGrainedPolicyAppliesTo | FGPP application targets | Returns what each policy applies to | 🟢 | Session-C |

**Validation Results**: All 11 tests passed validation against live DC (maester.test). See [AD-TEST-RESULTS.md](../../AD-TEST-RESULTS.md) for detailed results.

---

## Phase 4: DNS Infrastructure (AdRecon - DNSNodes.csv & DNSZones.csv)

**Phase Goal**: Implement tests for DNS configuration security
**Estimated Tests**: 19
**Dependencies**: None

**Status**: 🟢 Complete
**Completed By**: Session-D (Sisyphus)
**Implementation Date**: 2026-04-25
**Validation Date**: 2026-04-25
**Tests Completed**: 19/19
**Tests Validated**: 19/19

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-DNS-01 | DnsZoneCount | DNS Zones with records | Returns count of zones with records | 🟢 | Session-D |
| AD-DNS-02 | DnsZonesWithOnlySoaNs | Zones with only SOA/NS records | Returns count of zones with only default records | 🟢 | Session-D |
| AD-DNS-03 | DnsRootServerIncorrectCount | Root servers with incorrect IPs | Returns count of root servers with wrong IPs | 🟢 | Session-D |
| AD-DNS-04 | DnsRootServerIncorrectDetails | Details of incorrect root servers | Returns list of root servers with incorrect IPs | 🟢 | Session-D |
| AD-DNS-05 | DnsDynamicRecordCount | Dynamic DNS records count | Returns count of dynamic records | 🟢 | Session-D |
| AD-DNS-06 | DnsZonesWithRecordsCount | Zones with non-default records | Returns count of zones with custom records | 🟢 | Session-D |
| AD-DNS-07 | DnsZoneRecordDetails | Zone record count details | Returns breakdown of records per zone | 🟢 | Session-D |
| AD-DNS-08 | DnsZoneDelegationCount | Zone delegation count | Returns count of zone delegations | 🟢 | Session-D |
| AD-DNS-09 | DnsZoneDelegationDetails | Zone delegation details | Returns list of zone delegations | 🟢 | Session-D |
| AD-DNS-10 | DnsSoaDetails | SOA record details per zone | Returns SOA information for each zone | 🟢 | Session-D |
| AD-DNS-11 | DnsAdSrvRecordCount | AD DS SRV records count | Returns count of AD SRV records | 🟢 | Session-D |
| AD-DNS-12 | DnsAdSrvRecordDetails | AD DS SRV record details | Returns list of AD SRV records | 🟢 | Session-D |
| AD-DNS-13 | DnsDnssecRecordCount | DNSSEC records count | Returns count of DNSSEC trust anchors | 🟢 | Session-D |
| AD-DNS-14 | DnsEmptyZoneCount | Zones with zero records | Returns count of empty zones | 🟢 | Session-D |
| AD-DNS-15 | DnsDuplicateZoneCount | Duplicate/conflict zones | Returns count of duplicate zones (CNF) | 🟢 | Session-D |
| AD-DNS-16 | DnsReverseZoneCount | Reverse lookup zones | Returns count of reverse lookup zones | 🟢 | Session-D |
| AD-DNS-17 | DnsNonStandardZoneCount | Non-standard zone names | Returns count of zones not meeting RFC standards | 🟢 | Session-D |
| AD-DNS-18 | DnsReverseZoneNetworkCount | Networks with reverse zones | Returns count of networks with reverse lookup | 🟢 | Session-D |
| AD-DNS-19 | DnsReverseZoneNetworkDetails | Reverse zone network details | Returns list of networks with reverse zones | 🟢 | Session-D |

**Validation Results**: All 19 tests passed validation against live DC (maester.test). See [AD-TEST-RESULTS.md](../../AD-TEST-RESULTS.md) for detailed results.

---

## Phase 5: Domain & Forest Information (AdRecon - Domain.csv & Forest.csv)

**Phase Goal**: Implement tests for domain and forest configuration
**Estimated Tests**: 12
**Dependencies**: None

**Status**: 🟢 Complete
**Completed By**: Session-E (Sisyphus)
**Completed Date**: 2026-04-25
**Tests Completed**: 12/12

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-DOM-01 | DomainFunctionalLevel | Domain functional level | Returns current domain functional level | 🟢 | Session-E |
| AD-DOM-02 | MachineAccountQuota | Machine account quota value | Returns ms-DS-MachineAccountQuota (default: 10) | 🟢 | Session-E |
| AD-DOM-03 | DomainControllerCount | Domain controllers in domain | Returns count of DCs | 🟢 | Session-E |
| AD-DOM-04 | RidsRemaining | RIDs remaining in domain | Returns available RIDs | 🟢 | Session-E |
| AD-DOM-05 | DomainNameStandardCompliance | Domain name RFC compliance | Returns count of non-compliant domain names | 🟢 | Session-E |
| AD-DOM-06 | DomainNameNonStandardDetails | Non-standard domain name details | Returns list of non-compliant domain names | 🟢 | Session-E |
| AD-DOM-07 | NetbiosNameStandardCompliance | NetBIOS name compliance | Returns count of non-compliant NetBIOS names | 🟢 | Session-E |
| AD-DOM-08 | NetbiosNameNonStandardDetails | Non-standard NetBIOS details | Returns list of non-compliant NetBIOS names | 🟢 | Session-E |
| AD-FOR-01 | ForestFunctionalLevel | Forest functional level | Returns current forest functional level | 🟢 | Session-E |
| AD-FOR-02 | ForestDomainCount | Domains in forest | Returns count of domains in forest | 🟢 | Session-E |
| AD-FOR-03 | TombstoneLifetime | Tombstone lifetime in days | Returns tombstone lifetime (default: 60 or 180) | 🟢 | Session-E |
| AD-FOR-04 | RecycleBinStatus | AD Recycle Bin status | Returns whether recycle bin is enabled | 🟢 | Session-E |

---

## Phase 6: Domain Controllers (AdRecon - DomainControllers.csv)

**Phase Goal**: Implement tests for domain controller security
**Estimated Tests**: 8
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-DC-01 | DcSiteCoverageCount | Sites with active DCs | Returns count of sites with DCs | 🔴 | Unassigned |
| AD-DC-02 | DcSmbv1EnabledCount | DCs with SMBv1 enabled | Returns count of DCs with SMBv1 (should be 0) | 🔴 | Unassigned |
| AD-DC-03 | DcSmbv311EnabledCount | DCs with SMBv3.1.1 enabled | Returns count of DCs with SMBv3.1.1 | 🔴 | Unassigned |
| AD-DC-04 | DcSmbSigningEnabledCount | DCs with SMB signing enabled | Returns count of DCs with SMB signing | 🔴 | Unassigned |
| AD-DC-05 | DcAllFsmoRolesCount | DCs holding all 5 FSMO roles | Returns count of DCs with all FSMO roles | 🔴 | Unassigned |
| AD-DC-06 | DcFsmoRoleHolderDetails | FSMO role holder details | Returns list of DCs holding all FSMO roles | 🔴 | Unassigned |
| AD-DC-07 | DcOperatingSystemCount | Distinct DC operating systems | Returns count of unique OS environments | 🔴 | Unassigned |
| AD-DC-08 | DcOperatingSystemDetails | DC OS distribution details | Returns breakdown of DCs by OS | 🔴 | Unassigned |

---

## Phase 7: Group Policy (AdRecon - GPOs.csv & GpLinks.csv)

**Phase Goal**: Implement tests for Group Policy security
**Estimated Tests**: 11
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-GPO-01 | GpoTotalCount | Total GPOs in domain | Returns count of GPOs | 🔴 | Unassigned |
| AD-GPO-02 | GpoCreatedBefore2020Count | GPOs created before 2020 | Returns count of old GPOs | 🔴 | Unassigned |
| AD-GPO-03 | GpoChangedBefore2020Count | GPOs last changed before 2020 | Returns count of stale GPOs | 🔴 | Unassigned |
| AD-GPO-04 | GpoUnlinkedCount | GPOs with no links | Returns count of unlinked GPOs | 🔴 | Unassigned |
| AD-GPO-05 | GpoUnlinkedDetails | Details of unlinked GPOs | Returns list of unlinked GPOs | 🔴 | Unassigned |
| AD-GPOL-01 | GpoLinkedCount | Distinct GPOs with links | Returns count of linked GPOs | 🔴 | Unassigned |
| AD-GPOL-02 | GpoDisabledLinkCount | Disabled GPO links | Returns count of disabled links | 🔴 | Unassigned |
| AD-GPOL-03 | GpoUnlinkedTargetCount | Targets without GPO links | Returns count of targets with no GPOs | 🔴 | Unassigned |
| AD-GPOL-04 | GpoEnforcedCount | Enforced GPO links | Returns count of enforced GPOs | 🔴 | Unassigned |
| AD-GPOL-05 | GpoBlockedInheritanceCount | Targets blocking inheritance | Returns count of targets with blocked inheritance | 🔴 | Unassigned |
| AD-GPOL-06 | GpoLinkedOUCount | OUs with GPO links | Returns count of OUs with GPO links | 🔴 | Unassigned |

---

## Phase 8: Groups (AdRecon - Groups.csv, GroupMembers.csv, GroupChanges.csv)

**Phase Goal**: Implement tests for group security analysis
**Estimated Tests**: 22
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-GRP-01 | GroupAdminCount | Groups with AdminCount set | Returns count of groups with AdminCount | 🔴 | Unassigned |
| AD-GRP-02 | GroupInContainerCount | Groups in container objects | Returns count of groups in CN containers | 🔴 | Unassigned |
| AD-GRP-03 | GroupStaleCount | Groups last changed before 2020 | Returns count of stale groups | 🔴 | Unassigned |
| AD-GRP-04 | GroupWithManagerCount | Groups with manager set | Returns count of managed groups | 🔴 | Unassigned |
| AD-GRP-05 | GroupSidHistoryCount | Groups with SID History | Returns count of groups with SID History | 🔴 | Unassigned |
| AD-GRP-06 | GroupDistributionCount | Distribution groups | Returns count of distribution groups | 🔴 | Unassigned |
| AD-GRP-07 | GroupSecurityCount | Security groups | Returns count of security groups | 🔴 | Unassigned |
| AD-GRP-08 | GroupDomainLocalCount | Domain Local groups | Returns count of domain local groups | 🔴 | Unassigned |
| AD-GRP-09 | GroupGlobalCount | Global groups | Returns count of global groups | 🔴 | Unassigned |
| AD-GRP-10 | GroupUniversalCount | Universal groups | Returns count of universal groups | 🔴 | Unassigned |
| AD-GMC-01 | GroupMemberDistinctGroupCount | Distinct groups with members | Returns count of groups with members | 🔴 | Unassigned |
| AD-GMC-02 | GroupMemberAccountTypeCount | Types of group members | Returns count of member account types | 🔴 | Unassigned |
| AD-GMC-03 | GroupMemberAccountTypeDetails | Member account type breakdown | Returns breakdown of member types | 🔴 | Unassigned |
| AD-GMC-04 | GroupMemberTrustCount | Trust members in groups | Returns count of trust members | 🔴 | Unassigned |
| AD-GMC-05 | GroupMemberTrustDetails | Trust member details | Returns breakdown of trust members by group | 🔴 | Unassigned |
| AD-GMC-06 | GroupMemberForeignSidCount | Foreign SID principals | Returns count of foreign security principals | 🔴 | Unassigned |
| AD-GMC-07 | GroupMemberForeignSidDetails | Foreign SID details | Returns breakdown by domain ID | 🔴 | Unassigned |
| AD-GMC-08 | GroupEmptyNonPrivilegedCount | Empty non-privileged groups | Returns count of empty non-privileged groups | 🔴 | Unassigned |
| AD-GMC-09 | GroupEmptyNonPrivilegedDetails | Empty non-privileged group details | Returns list of empty non-privileged groups | 🔴 | Unassigned |
| AD-GMC-10 | GroupPrivilegedWithMembersCount | Privileged groups with members | Returns count of privileged groups with members | 🔴 | Unassigned |
| AD-GMC-11 | GroupPrivilegedWithMembersDetails | Privileged group member details | Returns list of privileged groups with member counts | 🔴 | Unassigned |
| AD-GCHG-01 | GroupChangeAveragePerYear | Average group additions per year | Returns average additions per year | 🔴 | Unassigned |

---

## Phase 9: Users (AdRecon - Users.csv)

**Phase Goal**: Implement tests for user account security
**Estimated Tests**: 29
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-USER-01 | UserDisabledCount | Disabled user objects | Returns count of disabled users | 🔴 | Unassigned |
| AD-USER-02 | UserDormantEnabledCount | Enabled dormant users (>90 days) | Returns count of dormant enabled users | 🔴 | Unassigned |
| AD-USER-03 | UserPasswordNeverExpiresCount | Enabled users with non-expiring passwords | Returns count (should be minimal) | 🔴 | Unassigned |
| AD-USER-04 | UserReversibleEncryptionCount | Users with reversible encryption | Returns count (should be 0) | 🔴 | Unassigned |
| AD-USER-05 | UserDelegationAllowedCount | Users allowed for delegation | Returns count of users with delegation | 🔴 | Unassigned |
| AD-USER-06 | UserKerberosDesOnlyCount | Users using DES only | Returns count (should be 0) | 🔴 | Unassigned |
| AD-USER-07 | UserNoPreAuthCount | Users not requiring pre-authentication | Returns count (should be 0) | 🔴 | Unassigned |
| AD-USER-08 | UserNeverLoggedInCount | Enabled users never logged in | Returns count of never-logged-in users | 🔴 | Unassigned |
| AD-USER-09 | UserPasswordNotRequiredCount | Users not requiring password | Returns count (should be 0) | 🔴 | Unassigned |
| AD-USER-10 | UserWorkstationRestrictionCount | Users with workstation restrictions | Returns count of restricted users | 🔴 | Unassigned |
| AD-USER-11 | UserAdminCountCount | Users with AdminCount set | Returns count of admin-count users | 🔴 | Unassigned |
| AD-USER-12 | UserNonStandardPrimaryGroupCount | Users with non-standard primary group | Returns count of users not in group 513 | 🔴 | Unassigned |
| AD-USER-13 | UserSidHistoryCount | Users with SID History | Returns count of users with SID History | 🔴 | Unassigned |
| AD-USER-14 | UserSpnSetCount | Users with SPN configured | Returns count of users with SPNs | 🔴 | Unassigned |
| AD-USER-15 | UserManagerSetCount | Users with manager attribute | Returns count of users with manager | 🔴 | Unassigned |
| AD-USER-16 | UserHomeDirectoryCount | Users with home directory | Returns count of users with home directory | 🔴 | Unassigned |
| AD-USER-17 | UserProfilePathCount | Users with profile path | Returns count of users with profile path | 🔴 | Unassigned |
| AD-USER-18 | UserScriptPathCount | Users with logon script | Returns count of users with script path | 🔴 | Unassigned |
| AD-USER-19 | UserInContainerCount | Users in container objects | Returns count of users in CN containers | 🔴 | Unassigned |
| AD-USER-20 | UserKnownServiceAccountCount | Known service accounts identified | Returns count of known service accounts | 🔴 | Unassigned |
| AD-USER-21 | UserKnownServiceAccountDetails | Known service account details | Returns list of known service accounts | 🔴 | Unassigned |
| AD-USER-22 | UserBuiltInAdminCount | Built-in administrator accounts | Returns count of built-in admin accounts | 🔴 | Unassigned |
| AD-USER-23 | UserBuiltInAdminEnabledDetails | Enabled built-in admin details | Returns list of enabled built-in admins | 🔴 | Unassigned |
| AD-USER-24 | UserBuiltInAdminLastLogonDetails | Built-in admin last logon | Returns last logon for built-in admins | 🔴 | Unassigned |
| AD-USER-25 | UserBuiltInAdminPasswordAgeDetails | Built-in admin password age | Returns password last set for built-in admins | 🔴 | Unassigned |
| AD-USER-26 | UserHoneyPotCount | Honey pot users identified | Returns count of potential honey pot users | 🔴 | Unassigned |
| AD-USER-27 | UserHoneyPotDetails | Honey pot user details | Returns list of potential honey pot users | 🔴 | Unassigned |
| AD-USER-28 | UserDelegationConfiguredCount | Users with delegation configured | Returns count of users with delegation settings | 🔴 | Unassigned |
| AD-USER-29 | UserDelegationDetails | User delegation details | Returns breakdown of user delegations | 🔴 | Unassigned |

---

## Phase 10: Organizational Units (AdRecon - OUs.csv)

**Phase Goal**: Implement tests for OU structure analysis
**Estimated Tests**: 5
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-OU-01 | OuOverlappingNameCount | OUs with overlapping names | Returns count of OUs with duplicate names | 🔴 | Unassigned |
| AD-OU-02 | OuAtDomainRootCount | OUs at domain root level | Returns count of root-level OUs | 🔴 | Unassigned |
| AD-OU-03 | OuStaleCount | OUs last changed before 2020 | Returns count of stale OUs | 🔴 | Unassigned |
| AD-OU-04 | OuEmptyCount | OUs without user/group/computer objects | Returns count of empty OUs | 🔴 | Unassigned |
| AD-OU-05 | OuEmptyDetails | Empty OU details | Returns list of empty OUs | 🔴 | Unassigned |

---

## Phase 11: Sites and Subnets (AdRecon - Sites.csv & Subnets.csv)

**Phase Goal**: Implement tests for AD site topology
**Estimated Tests**: 16
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-SITE-01 | SiteTotalCount | Total sites in domain | Returns count of sites | 🔴 | Unassigned |
| AD-SITE-02 | SiteWithoutDcCount | Sites without domain controllers | Returns count of sites without DCs | 🔴 | Unassigned |
| AD-SITE-03 | SiteWithoutDcDetails | Sites without DC details | Returns list of sites without DCs | 🔴 | Unassigned |
| AD-SITE-04 | SiteWithoutSubnetCount | Sites without subnet associations | Returns count of sites without subnets | 🔴 | Unassigned |
| AD-SITE-05 | SiteWithoutSubnetDetails | Sites without subnet details | Returns list of sites without subnets | 🔴 | Unassigned |
| AD-SUB-01 | SubnetTotalCount | Total subnets configured | Returns count of subnets | 🔴 | Unassigned |
| AD-SUB-02 | SubnetSiteAssociationCount | Distinct sites with subnets | Returns count of sites with subnet associations | 🔴 | Unassigned |
| AD-SUB-03 | SubnetCatchAllCount | Catch-all subnets (RFC1918) | Returns count of overly broad subnets | 🔴 | Unassigned |
| AD-SUB-04 | SubnetIpv6Count | IPv6 subnets configured | Returns count of IPv6 subnets | 🔴 | Unassigned |
| AD-SUB-05 | SubnetIpv6CatchAllCount | IPv6 catch-all subnets | Returns count of IPv6 catch-all subnets | 🔴 | Unassigned |
| AD-SUB-06 | SubnetNonInternalCount | Non-RFC1918 subnets | Returns count of public IP subnets | 🔴 | Unassigned |
| AD-SUB-07 | SubnetNonInternalDetails | Non-RFC1918 subnet details | Returns list of public IP subnets | 🔴 | Unassigned |
| AD-SUB-08 | SubnetFirstOctetCount | Distinct first octets used | Returns count of unique first octets | 🔴 | Unassigned |
| AD-SUB-09 | SubnetFirstTwoOctetsCount | Distinct first two octets used | Returns count of unique /16 networks | 🔴 | Unassigned |
| AD-SUB-10 | SubnetFirstThreeOctetsCount | Distinct first three octets used | Returns count of unique /24 networks | 🔴 | Unassigned |
| AD-SUB-11 | SubnetWithoutSiteCount | Subnets without site associations | Returns count of orphaned subnets | 🔴 | Unassigned |

---

## Phase 12: Trusts (AdRecon - Trusts.csv)

**Phase Goal**: Implement tests for domain trust security
**Estimated Tests**: 7
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-TRUST-01 | TrustTotalCount | Total trusts in domain | Returns count of trusts | 🔴 | Unassigned |
| AD-TRUST-02 | TrustInterForestCount | Inter-forest trusts | Returns count of external trusts | 🔴 | Unassigned |
| AD-TRUST-03 | TrustQuarantinedCount | Quarantined trusts | Returns count of quarantined trusts | 🔴 | Unassigned |
| AD-TRUST-04 | TrustNonQuarantinedDetails | Non-quarantined trust details | Returns list of non-quarantined trusts | 🔴 | Unassigned |
| AD-TRUST-05 | TrustDetails | Trust configuration details | Returns list of all trusts with attributes | 🔴 | Unassigned |
| AD-TRUST-06 | TrustStaleCount | Stale trusts (>60 days) | Returns count of stale trusts | 🔴 | Unassigned |
| AD-TRUST-07 | TrustStaleDetails | Stale trust details | Returns list of stale trusts | 🔴 | Unassigned |

---

## Phase 13: Schema and Infrastructure (AdRecon - SchemaHistory.csv, Printers.csv)

**Phase Goal**: Implement tests for schema and infrastructure
**Estimated Tests**: 7
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-SCH-01 | SchemaModificationYearCount | Years with schema modifications | Returns count of years with schema changes | 🔴 | Unassigned |
| AD-SCH-02 | SchemaModificationYearDetails | Schema modifications per year | Returns breakdown of schema changes by year | 🔴 | Unassigned |
| AD-SCH-03 | SchemaVersionEntryCount | Schema version entries | Returns count of schema version entries | 🔴 | Unassigned |
| AD-SCH-04 | SchemaVersionDetails | Schema version details | Returns list of schema versions with dates | 🔴 | Unassigned |
| AD-SCH-05 | LapsInstalledStatus | LAPS installation status | Returns whether LAPS is installed | 🔴 | Unassigned |
| AD-PRINT-01 | PrinterTotalCount | Total printers in domain | Returns count of printers | 🔴 | Unassigned |

---

## Phase 14: Domain State - Configuration (DomainState - get-AdConfiguration.json)

**Phase Goal**: Implement tests for AD configuration objects
**Estimated Tests**: 24
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-CFG-01 | TombstoneLifetimeConfig | Tombstone lifetime from config | Returns tombstone lifetime days | 🔴 | Unassigned |
| AD-CFG-02 | DsHeuristicsCount | dSHeuristics in use | Returns count of dSHeuristics settings | 🔴 | Unassigned |
| AD-CFG-03 | SpnMappings | SPN Mappings configured | Returns list of SPN mappings | 🔴 | Unassigned |
| AD-CFG-04 | OptionalFeaturesCount | Optional features available | Returns count of optional features | 🔴 | Unassigned |
| AD-CFG-05 | RecycleBinEnabledPaths | Recycle bin enabled paths | Returns count of paths with recycle bin | 🔴 | Unassigned |
| AD-CFG-06 | LdapQueryPolicyCount | LDAP query policies | Returns count of query policies | 🔴 | Unassigned |
| AD-CFG-07 | DefaultQueryPolicy | Default query policy settings | Returns default query policy limits | 🔴 | Unassigned |
| AD-CFG-08 | AuthNPolicyConfigCount | Authentication policy containers | Returns count of auth policy containers | 🔴 | Unassigned |
| AD-CFG-09 | AdActivationObjectsCount | AD-based activation objects | Returns count of activation objects | 🔴 | Unassigned |
| AD-CFG-10 | WellKnownSecurityPrincipalsCount | Well-known security principals | Returns count (27 is default) | 🔴 | Unassigned |
| AD-CFG-11 | RegisteredDhcpServersCount | DHCP servers registered in AD | Returns count of registered DHCP servers | 🔴 | Unassigned |
| AD-CFG-12 | EnterpriseCaCount | Enterprise certificate authorities | Returns count of enrollment CAs | 🔴 | Unassigned |
| AD-CFG-13 | CertificateTemplatesCount | Certificate templates in AD | Returns count of certificate templates | 🔴 | Unassigned |
| AD-CFG-14 | EnrollmentTemplatesCount | Templates available for enrollment | Returns count of enrollment templates | 🔴 | Unassigned |
| AD-CFG-15 | EnrollmentCaCertificateDetails | Enrollment CA certificate details | Returns list of enrollment CAs with validity | 🔴 | Unassigned |
| AD-CFG-16 | TrustedRootCaCount | Trusted root CAs configured | Returns count of trusted root CAs | 🔴 | Unassigned |
| AD-CFG-17 | TrustedRootCaDetails | Trusted root CA details | Returns list of root CAs with validity | 🔴 | Unassigned |
| AD-CFG-18 | IntermediateCaCount | Intermediate CAs configured | Returns count of intermediate CAs | 🔴 | Unassigned |
| AD-CFG-19 | IntermediateCaDetails | Intermediate CA details | Returns list of intermediate CAs with validity | 🔴 | Unassigned |
| AD-CFG-20 | CrlDistributionPointsCount | CRL distribution points | Returns count of CDPs | 🔴 | Unassigned |
| AD-CFG-21 | NtAuthCertificatesCount | NTAuth certificates count | Returns count of smart card/archive CAs | 🔴 | Unassigned |
| AD-CFG-22 | KdsRootKeysCount | KDS root keys for gMSA | Returns count of KDS root keys | 🔴 | Unassigned |
| AD-CFG-23 | SmtpSiteLinksCount | SMTP site links available | Returns count of SMTP site links | 🔴 | Unassigned |
| AD-CFG-24 | IpSiteLinksCount | IP site links available | Returns count of IP site links | 🔴 | Unassigned |

---

## Phase 15: Domain State - Domain Controllers (DomainState - get-AdDomainController.json)

**Phase Goal**: Implement tests for DC configuration details
**Estimated Tests**: 4
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-DCD-01 | DcNonStandardLdapPortCount | DCs with non-standard LDAP port | Returns count of DCs not using 389 | 🔴 | Unassigned |
| AD-DCD-02 | DcNonStandardLdapsPortCount | DCs with non-standard LDAPS port | Returns count of DCs not using 636 | 🔴 | Unassigned |
| AD-DCD-03 | DcReadOnlyCount | Read-only domain controllers | Returns count of RODCs | 🔴 | Unassigned |
| AD-DCD-04 | DcNonGlobalCatalogCount | DCs not as Global Catalogs | Returns count of non-GC DCs | 🔴 | Unassigned |

---

## Phase 16: Domain State - Forest and Domain (DomainState - get-AdForest.json, get-AdDomain.json)

**Phase Goal**: Implement tests for forest and domain settings
**Estimated Tests**: 5
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-FORS-01 | UpnSuffixesCount | UPN suffixes configured | Returns count of UPN suffixes | 🔴 | Unassigned |
| AD-FORS-02 | UpnSuffixesDetails | UPN suffix details | Returns list of UPN suffixes | 🔴 | Unassigned |
| AD-FORS-03 | SpnSuffixesCount | SPN suffixes configured | Returns count of SPN suffixes | 🔴 | Unassigned |
| AD-FORS-04 | CrossForestReferencesCount | Cross-forest references | Returns count of cross-forest references | 🔴 | Unassigned |
| AD-DOMS-01 | AllowedDnsSuffixesCount | Allowed DNS suffixes | Returns count of allowed DNS suffixes | 🔴 | Unassigned |

---

## Phase 17: Domain State - Security Accounts (DomainState - get-AdKrbtgt.json, get-AdComputer.json, get-AdServiceAccount.json)

**Phase Goal**: Implement tests for security principal configuration
**Estimated Tests**: 13
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-KRBTGT-01 | KrbtgtPasswordLastSet | KRBTGT password last set date | Returns datetime of last password change | 🔴 | Unassigned |
| AD-KRBTGT-02 | KrbtgtLastLogon | KRBTGT last logon time | Returns datetime of last logon | 🔴 | Unassigned |
| AD-KRBTGT-03 | KrbtgtNonStandardUacCount | KRBTGT non-standard UAC state | Returns count of non-standard UAC (should be 0) | 🔴 | Unassigned |
| AD-DCOMP-01 | ComputerUnconstrainedDelegationCount | Computers with unconstrained delegation | Returns count (should be minimal) | 🔴 | Unassigned |
| AD-DCOMP-02 | ComputerNonDcUnconstrainedDelegationCount | Non-DC computers with unconstrained delegation | Returns count (should be 0) | 🔴 | Unassigned |
| AD-DCOMP-03 | ComputerNonDcConstrainedDelegationCount | Non-DC computers with constrained delegation | Returns count (should be minimal) | 🔴 | Unassigned |
| AD-DCOMP-04 | ComputerOperatingSystemCount | Distinct computer OS environments | Returns count of unique OS types | 🔴 | Unassigned |
| AD-DCOMP-05 | ComputerOperatingSystemDetails | Computer OS distribution | Returns breakdown of computers by OS | 🔴 | Unassigned |
| AD-DCOMP-06 | ComputerStaleEnabledCount | Enabled computers not logged in 180 days | Returns count of stale enabled computers | 🔴 | Unassigned |
| AD-DCOMP-07 | ComputerDnsHostNameCount | Computers with DNS host name | Returns count of computers with DNS registration | 🔴 | Unassigned |
| AD-DCOMP-08 | ComputerDnsZoneCount | DNS zones used by computers | Returns count of unique DNS zones | 🔴 | Unassigned |
| AD-DCOMP-09 | ComputerDnsZoneDetails | Computer DNS zone distribution | Returns breakdown of computers by DNS zone | 🔴 | Unassigned |
| AD-MSA-01 | ManagedServiceAccountCount | Managed service accounts | Returns count of MSAs | 🔴 | Unassigned |

---

## Phase 18: Domain State - Replication and Features (DomainState - get-AdReplicationConnection.json, get-AdOptionalFeature.json, get-AdRootDse.json)

**Phase Goal**: Implement tests for replication and optional features
**Estimated Tests**: 8
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-REPL-01 | DisabledReplicationConnectionCount | Disabled replication connections | Returns count of disabled connections (should be 0) | 🔴 | Unassigned |
| AD-REPL-02 | NonAutoReplicationConnectionCount | Non-auto-generated replication connections | Returns count of manual connections | 🔴 | Unassigned |
| AD-FEAT-01 | OptionalFeatureCount | Optional features count | Returns count of optional features | 🔴 | Unassigned |
| AD-FEAT-02 | OptionalFeatureEnabledDetails | Enabled optional feature details | Returns list of features with enabled scopes | 🔴 | Unassigned |
| AD-ROOTDSE-01 | SupportedSaslMechanismCount | Supported SASL mechanisms | Returns count (4 is default) | 🔴 | Unassigned |
| AD-ROOTDSE-02 | SupportedSaslMechanismDetails | SASL mechanism details | Returns list of supported SASL mechanisms | 🔴 | Unassigned |
| AD-ROOTDSE-03 | RootDseSynchronizedStatus | Root DSE synchronization status | Returns whether Root DSE is synchronized | 🔴 | Unassigned |
| AD-DFSR-01 | DfsrSubscriptionCount | DCs in SYSVOL DFS-R subscription | Returns count of DCs in DFS-R | 🔴 | Unassigned |

---

## Phase 19: GPO State (GpoState - get-gpo.json, GpoReports)

**Phase Goal**: Implement tests for GPO detailed state
**Estimated Tests**: 26
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-GPOS-01 | GpoStateTotalCount | Total GPOs from state | Returns count of GPOs | 🔴 | Unassigned |
| AD-GPOS-02 | GpoWmiFilterCount | GPOs with WMI filters | Returns count of GPOs with WMI filters | 🔴 | Unassigned |
| AD-GPOS-03 | GpoWmiFilterDetails | WMI filter details | Returns list of GPOs with WMI filter names | 🔴 | Unassigned |
| AD-GPOS-04 | GpoSettingsDisabledCount | GPOs with settings disabled | Returns count of GPOs with disabled settings | 🔴 | Unassigned |
| AD-GPOS-05 | GpoComputerSettingsDisabledDetails | Computer settings disabled details | Returns list of GPOs with computer settings disabled | 🔴 | Unassigned |
| AD-GPOS-06 | GpoUserSettingsDisabledDetails | User settings disabled details | Returns list of GPOs with user settings disabled | 🔴 | Unassigned |
| AD-GPOS-07 | GpoAllSettingsDisabledDetails | All settings disabled details | Returns list of completely disabled GPOs | 🔴 | Unassigned |
| AD-GPOS-08 | GpoOwnerDistinctCount | Distinct GPO owners | Returns count of unique GPO owners | 🔴 | Unassigned |
| AD-GPOS-09 | GpoOwnerDetails | GPO ownership distribution | Returns breakdown of GPOs by owner | 🔴 | Unassigned |
| AD-GPOREP-01 | GpoNoPermissionsCount | GPOs without permissions | Returns count of GPOs without permissions set | 🔴 | Unassigned |
| AD-GPOREP-02 | GpoNoPermissionsDetails | GPOs without permissions details | Returns list of GPOs without permissions | 🔴 | Unassigned |
| AD-GPOREP-03 | GpoNoAuthenticatedUsersCount | GPOs without Authenticated Users | Returns count of GPOs missing Auth Users | 🔴 | Unassigned |
| AD-GPOREP-04 | GpoNoAuthenticatedUsersDetails | Missing Authenticated Users details | Returns list of GPOs without Auth Users | 🔴 | Unassigned |
| AD-GPOREP-05 | GpoNoEnterpriseDcCount | GPOs without Enterprise Domain Controllers | Returns count missing Enterprise DCs | 🔴 | Unassigned |
| AD-GPOREP-06 | GpoNoDomainComputersCount | GPOs without Domain Computers | Returns count missing Domain Computers | 🔴 | Unassigned |
| AD-GPOREP-07 | GpoDenyAceCount | GPOs with deny ACEs | Returns count of GPOs with deny entries | 🔴 | Unassigned |
| AD-GPOREP-08 | GpoDenyAceDetails | Deny ACE details | Returns list of GPOs with deny entries | 🔴 | Unassigned |
| AD-GPOREP-09 | GpoInheritedPermissionsCount | GPOs using inherited permissions | Returns count of GPOs with inherited perms | 🔴 | Unassigned |
| AD-GPOREP-10 | GpoNoApplyGroupPolicyAceCount | GPOs without Apply Group Policy ACE | Returns count missing Apply GP permission | 🔴 | Unassigned |
| AD-GPOREP-11 | GpoNoApplyGroupPolicyAceDetails | Missing Apply GP ACE details | Returns list of GPOs without Apply GP | 🔴 | Unassigned |
| AD-GPOREP-12 | GpoDisabledLinkCount | GPOs with disabled links | Returns count of GPOs with disabled links | 🔴 | Unassigned |
| AD-GPOREP-13 | GpoDisabledLinkDetails | Disabled link details | Returns list of GPOs with disabled links | 🔴 | Unassigned |
| AD-GPOREP-14 | GpoEnforcementCount | GPOs with enforcement | Returns count of enforced GPOs | 🔴 | Unassigned |
| AD-GPOREP-15 | GpoVersionMismatchCount | GPOs with version mismatches | Returns count of GPOs with dir/Sysvol mismatch | 🔴 | Unassigned |
| AD-GPOREP-16 | GpoVersionMismatchDetails | Version mismatch details | Returns list of GPOs with version mismatches | 🔴 | Unassigned |
| AD-GPOREP-17 | GpoCpasswordFoundCount | GPOs with Cpassword entries | Returns count of GPOs with encrypted passwords | 🔴 | Unassigned |
| AD-GPOREP-18 | GpoCpasswordFoundDetails | Cpassword entry details | Returns list of GPOs with Cpassword | 🔴 | Unassigned |
| AD-GPOREP-19 | GpoDefaultPasswordFoundCount | GPOs with DefaultPassword entries | Returns count of GPOs with default passwords | 🔴 | Unassigned |
| AD-GPOREP-20 | GpoDefaultPasswordFoundDetails | DefaultPassword entry details | Returns list of GPOs with default passwords | 🔴 | Unassigned |

---

## Phase 20: DACL Analysis (AdDacls - Get-Acls-*.csv)

**Phase Goal**: Implement tests for discretionary access control list analysis
**Estimated Tests**: 18
**Dependencies**: None

| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-DACL-01 | DaclDistinctObjectCount | Distinct objects with DACLs | Returns count of unique objects with DACLs | 🔴 | Unassigned |
| AD-DACL-02 | DaclOuObjectCount | DACL entries on OU objects | Returns count of ACEs on OUs | 🔴 | Unassigned |
| AD-DACL-03 | DaclConflictObjectCount | Conflict objects in DACLs | Returns count of conflict objects (CNF) | 🔴 | Unassigned |
| AD-DACL-04 | DaclConflictObjectDetails | Conflict object details | Returns list of conflict objects | 🔴 | Unassigned |
| AD-DACL-05 | DaclDenyAceCount | Deny authorization ACEs | Returns count of deny ACEs | 🔴 | Unassigned |
| AD-DACL-06 | DaclDenyAceDetails | Deny ACE details | Returns breakdown of deny authorizations | 🔴 | Unassigned |
| AD-DACL-07 | DaclDistinctIdentityCount | Distinct identities in ACEs | Returns count of unique identities | 🔴 | Unassigned |
| AD-DACL-08 | DaclIdentityAceDistribution | ACE distribution per identity | Returns breakdown of ACEs by identity | 🔴 | Unassigned |
| AD-DACL-09 | DaclPrivilegedAllowAceCount | Privileged allow ACE types | Returns count of privileged allow ACE types | 🔴 | Unassigned |
| AD-DACL-10 | DaclPrivilegedAllowAceDetails | Privileged allow ACE details | Returns breakdown of privileged allow ACEs | 🔴 | Unassigned |
| AD-DACL-11 | DaclPrivilegedExtendedRightCount | Privileged extended rights | Returns count of privileged extended rights | 🔴 | Unassigned |
| AD-DACL-12 | DaclPrivilegedExtendedRightDetails | Privileged extended right details | Returns breakdown of privileged extended rights | 🔴 | Unassigned |
| AD-DACL-13 | DaclPrivilegedExtendedRightIdentity | Identity privileged extended rights | Returns identities with privileged rights | 🔴 | Unassigned |
| AD-DACL-14 | DaclNonInheritedAceCount | Non-inherited ACEs | Returns count of non-inherited ACEs | 🔴 | Unassigned |
| AD-DACL-15 | DaclUnresolvedSidCount | Unresolvable SIDs in ACEs | Returns count of orphaned SIDs | 🔴 | Unassigned |
| AD-DACL-16 | DaclUnresolvedSidDetails | Unresolvable SID details | Returns list of orphaned SIDs | 🔴 | Unassigned |
| AD-DACL-17 | DaclInheritedObjectTypeCount | Inherited object types | Returns count of inherited object types | 🔴 | Unassigned |
| AD-DACL-18 | DaclInheritedObjectTypeDetails | Inherited object type details | Returns breakdown by inherited object type | 🔴 | Unassigned |

---

## Summary Statistics

| Phase | Category | Test Count | Status |
|-------|----------|------------|--------|
| Phase 1 | Computer Objects | 10 | 🟢 Complete |
| Phase 2 | Service Principal Names | 13 | 🟢 Complete |
| Phase 3 | Password Policies | 11 | 🟢 Complete |
| Phase 4 | DNS Infrastructure | 19 | 🟢 Complete |
| Phase 5 | Domain & Forest | 12 | 🟢 Complete |
| Phase 6 | Domain Controllers | 8 | 🔴 Not Started |
| Phase 7 | Group Policy | 11 | 🔴 Not Started |
| Phase 8 | Groups | 22 | 🔴 Not Started |
| Phase 9 | Users | 29 | 🔴 Not Started |
| Phase 10 | Organizational Units | 5 | 🔴 Not Started |
| Phase 11 | Sites and Subnets | 16 | 🔴 Not Started |
| Phase 12 | Trusts | 7 | 🔴 Not Started |
| Phase 13 | Schema and Infrastructure | 7 | 🔴 Not Started |
| Phase 14 | Domain State - Configuration | 24 | 🔴 Not Started |
| Phase 15 | Domain State - DCs | 4 | 🔴 Not Started |
| Phase 16 | Domain State - Forest/Domain | 5 | 🔴 Not Started |
| Phase 17 | Domain State - Security Accounts | 13 | 🔴 Not Started |
| Phase 18 | Domain State - Replication/Features | 8 | 🔴 Not Started |
| Phase 19 | GPO State | 26 | 🔴 Not Started |
| Phase 20 | DACL Analysis | 18 | 🔴 Not Started |
| **TOTAL** | | **268** | **24% Complete (65/268)** |

---

## Next Steps

1. Select a phase to implement (recommended: start with Phase 1 - Computer Objects)
2. Review the [Single Test Implementation Work Plan](./SingleTestWorkPlan.md)
3. Update this backlog to mark tests as "In Progress" with your name
4. Follow the implementation pattern in the work plan
5. **Commit and push changes** (see Commit and Push Guidelines below)
6. **Validate all tests against the live domain controller** (see Validation Requirements below)
7. Update status to "Complete" when finished

## Commit and Push Guidelines (REQUIRED - DO NOT SKIP)

**⚠️ CRITICAL: COMMIT AND PUSH IS A REQUIRED STEP ⚠️**

After completing a phase, you **MUST** commit and push your changes to the repository. A phase is **NOT COMPLETE** until changes are pushed.

### Why This Matters
- **Collaboration**: Other sessions need access to your changes
- **Backup**: Prevents loss of work
- **Consistency**: Ensures backlog reflects actual state
- **History**: Maintains audit trail of changes

### Commit Steps:

1. **Stage all relevant files** (do not use `git add .`):
   ```bash
   git add powershell/public/ad/[category]/
   git add tests/ad/[category]/
   git add powershell/Maester.psd1
   git add powershell/public/Get-MtADDomainState.ps1
   git add build/activeDirectory/ADTestBacklog.md
   ```

2. **Verify what will be committed**:
   ```bash
   git status
   ```

3. **Commit with descriptive message**:
   ```bash
   git commit -m "Complete Phase X: [Phase Name] - Y tests implemented
   
   - Added Y test functions in powershell/public/ad/[category]/
   - Added Y Pester test files in tests/ad/[category]/
   - Added Y markdown documentation files
   - Updated Maester.psd1 module manifest with new function exports
   - Updated ADTestBacklog.md to mark Phase X complete"
   ```

4. **Push to the remote repository**:
   ```bash
   git push origin [branch-name]
   ```

5. **Verify push succeeded**:
   ```bash
   git log --oneline -3
   git status  # Should show "nothing to commit, working tree clean"
   ```

### Commit Checklist (REQUIRED):
- [ ] All new test function files are staged
- [ ] All new Pester test files are staged
- [ ] All new markdown documentation files are staged
- [ ] Maester.psd1 module manifest is staged (if updated)
- [ ] Get-MtADDomainState.ps1 is staged (if extended)
- [ ] ADTestBacklog.md is staged with updated status
- [ ] No temporary files, logs, or credentials are committed
- [ ] Commit message clearly describes the phase and number of tests
- [ ] Changes are committed locally
- [ ] Changes are pushed to the correct branch
- [ ] Push verified successful (`git log` shows your commit)

## Validation Requirements

**CRITICAL**: Before marking any phase as "Complete", all tests MUST be validated against the live domain controller:

### Validation Steps:
1. Connect to the domain controller:
   ```bash
   ssh -i ~/.ssh/test_key azureuser@20.125.96.137
   ```
2. Copy the updated Maester module to the DC:
   ```bash
   scp -r /home/azureuser/projects/maester/powershell/* azureuser@20.125.96.137:/tmp/
   ```
3. Run each test function against the live AD environment
4. Verify tests return expected results without errors
5. Document results in [AD-TEST-RESULTS.md](../../AD-TEST-RESULTS.md)

### Validation Checklist:
- [ ] All functions execute without errors
- [ ] Functions return expected data types (boolean or null)
- [ ] Markdown output is generated correctly
- [ ] Connection handling works (returns null when not connected)
- [ ] Results are documented in AD-TEST-RESULTS.md

### Domain Controller Information:
- **IP**: 20.125.96.137
- **Domain**: maester.test
- **Admin Password**: P@ssw0rd123!

## Collaboration Guidelines

- Each session should work on a single phase at a time
- Update the "Assigned To" column when starting work
- Commit changes frequently with clear messages
- **Commit and push changes after completing a phase** (see Commit and Push Guidelines above)
- **Validate tests against live DC before marking complete**
- Document any assumptions made about pass/fail criteria
