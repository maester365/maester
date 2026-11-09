HomeDirectory, ProfilePath and absolute ScriptPath entries are checked against `ApprovedPathPrefixes` (empty by default, so all populated absolute paths are unapproved). Prefix matching is case-insensitive and respects path-component boundaries. Parent traversal is rejected; relative NETLOGON scripts require review, not automatic failure. This check **does not inspect file or share ACLs**.

#### Control Type

**Detective**

#### Security Recommendation

Approve only verified home, profile and script-path roots and check file/share permissions independently. An approved prefix is not proof of safe ACLs.

#### How the Test Works

The test compares absolute paths with case-insensitive, path-component-aware `ApprovedPathPrefixes`, rejects parent traversal and sends relative NETLOGON scripts for review. It does not read file/share ACLs.



#### Remediation action
1. Verify affected home, profile and logon-script roots with their owners in [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Correct untrusted paths and approve only reviewed roots using `ApprovedPathPrefixes`. Inspect ACLs separately.

<!--- Results --->
%TestResult%
