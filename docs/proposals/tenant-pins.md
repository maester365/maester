# Design: tenant pins (tests Maester writes for your tenant)

> **Status: DRAFT.** Drafted 2026-11-09 against Maester 3.0 on `main`. Nothing is implemented. Section 17 lists
> the decisions the owner needs to make; each has a recommendation. The idea is discussed in
> [maester365/maester#2745](https://github.com/maester365/maester/issues/2745).

## 1. Summary

Maester's checks today ask one question of every tenant: *is this setting configured well?* They are the same
for everyone. This design adds a second question that only the tenant can answer: *is this still the way we
set it up?* Maester scans the tenant once, works out which objects its security depends on, writes down how
each one looks today, and from then on fails a test when one of them changes.

- **A pin** is one recorded fact about one object: "contoso.com is federated with issuer
  `http://sts.contoso.com/adfs/services/trust` and signing certificate `3F2A…91`", or "the group
  *CA-Exclude-BreakGlass* has exactly these two members". Each pin carries the reason Maester picked it.
- **Maester picks what to pin by following dependencies.** It starts from the controls that protect the tenant
  (Conditional Access, MFA, PIM, Intune compliance, Defender policy) and from the ways in (federation, trusted
  certificate authorities, partner tenants, privileged apps), and pins every object those depend on. A group is
  pinned because it is excluded from the MFA policy, not because of its name.
- **Pins are data, not code.** `New-MtTenantPin` writes a pin file, `maester-pins.<tenantId>.json`, next to
  `maester-config.json`. Maester ships one family test per *pin kind* (federated domain, CA exclusion group,
  Intune script, …); each family reads the pin file and produces one row per pin, such as
  `MT.13xx.contoso.com`. No generated code runs, and every improvement to a pin kind reaches every tenant.
- **A change fails the row and says what moved.** The row shows the pinned value, the current value and why it
  matters, and (milestone 3) who changed it, read from the audit logs. A change that weakens security is
  `Failed`; a change that tightens it is `Investigate`.
- **Accepting a change is a commit.** `Update-MtTenantPin` re-records the pins the admin accepts and adds
  objects that have become critical since the last scan. In a repository the update is a pull request, so the
  review of the change and the approval of the new state are the same step.
- **An agent skill adds judgement on top.** A user-facing skill lets the admin's AI agent propose pins that
  dependencies cannot find (the payroll app's credentials, the CFO's authentication methods) using the same
  pin kinds, and write a custom test with `New-MtTest` when no kind fits. The AI proposes; the pin file is the
  contract; nothing at run time depends on a model.

## 2. The problem

Generic checks cannot see what a tenant relies on. Three examples:

- **Federation.** Maester can say that a tenant should not federate with an insecure IdP. It cannot say that
  contoso.com's token-signing certificate is `3F2A…91` and nothing else. Replacing that certificate, or
  federating a second domain with an IdP someone else runs, lets that party sign tokens for the tenant's users
  (MITRE T1484.002, T1606.002). Every setting stays "valid", so every generic check still passes.
- **Exclusions.** MT.1005 checks that every CA policy excludes a break-glass account. Nothing notices when a
  third user joins the exclusion group. The membership of an exclusion group *is* the policy, and adding a
  member is the quietest way around MFA.
- **Indirect dependencies.** A CA policy that requires a compliant device is only as strong as the compliance
  policies that define "compliant" and the groups they are assigned to. Removing the BitLocker requirement from
  a compliance policy, or editing the assignment filter, weakens the CA policy without touching it.

Admins could write these tests themselves: MT.1060 already compares a `baseline.json` with a `current.json`.
Few do, because they would have to know which objects matter, export them, and keep the files current. This
design moves all three jobs into Maester.

What this is not:

- Not a replacement for the generic checks: a pinned value can be bad. Pins say "unchanged", not "good".
- Not real time. Pins are checked when Maester runs (typically daily). A SIEM alert on "Set federation
  settings on domain" is faster; a pin catches changes made by any route, needs no SIEM, and states the
  approved value.
- Not a backup or desired-state tool. Pins never write to the tenant and record only what matters to security.
  Microsoft365DSC and Microsoft's tenant configuration management APIs (section 15) cover whole-tenant snapshots.

## 3. Terms

| Term | Meaning |
| --- | --- |
| Anchor | An object security depends on: a federated domain, an exclusion group, a trusted CA, an Intune script. |
| Pin | One anchor plus the properties recorded for it, the reason it was picked and who approved it. |
| Pin kind | A kind of anchor that Maester knows how to find, record and compare, such as `entra.domain-federation`. Each kind is one family test. |
| Pin file | `maester-pins.<tenantId>.json`: every pin for one tenant. Owned by the admin, kept in their Maester folder. |
| Scan | `New-MtTenantPin` or `Update-MtTenantPin -Discover`: finding anchors and recording them. |
| Accept | Recording the current value of a changed pin, so that it passes again. |

## 4. Options considered

| Option | What it means | Verdict |
| --- | --- | --- |
| An AI agent writes a test per anchor | A skill reads the tenant and writes `Test.CONTOSO.<n>.ps1` files with the values in the code | No as the main route: a different result on every run, hundreds of files to review, and nothing improves when Maester does. Kept as a proposal layer (section 12). |
| Generate static test files from templates | `New-MtTenantPin` writes one test file per anchor | No: the same staleness. A fix to how federation is compared would mean regenerating every tenant's files, and admins would edit them and lose updates. |
| **Pin file + one family per pin kind** | The scan writes data; Maester's families read it | **Chosen.** The file is small and reviewable in a diff, the logic is versioned and unit tested in Maester, and families already exist in 3.0. |
| Build on Microsoft's configuration monitors | Create UTCM monitors (`/admin/configurationManagement`) and read their drifts | Not now: beta, needs write permission to create monitors (Maester is read-only), and it watches whatever resources it is told to, without knowing why one matters. Revisit as a reader (section 15). |

## 5. End to end

```powershell
Connect-Maester
New-MtTenantPin                      # scan, then write ./maester-pins.<tenantId>.json
Invoke-Maester                       # every pin passes: nothing has changed yet
```

`New-MtTenantPin` prints what it found, grouped by kind, with the reason for each:

```text
Pinned 63 objects in contoso.onmicrosoft.com (9f1c…)

  Federated domains                 2   contoso.com, fabrikam.com (AD FS)
  Domain federation settings        2   issuer, signing and next signing certificate
  Conditional Access policies      14   12 enabled, 2 report-only
  CA exclusion groups               4   CA-Exclude-BreakGlass excluded from 14 policies
  CA trusted locations              2   HQ-Egress used to skip MFA in 'CA003 Require MFA'
  Emergency access accounts         2   from EmergencyAccessAccounts
  Privileged role members          11   Global Administrator (3), Privileged Role Administrator (2), …
  Privileged apps                   6   hold RoleManagement.ReadWrite.Directory or similar
  Intune compliance policies        5   CA003 requires a compliant device
  Intune scripts                    3   'Set-Baseline.ps1' runs as SYSTEM on All devices
  …

Review the file, commit it, and run Invoke-Maester. Accept a change later with Update-MtTenantPin.
```

From then on:

1. **A run** reads the pin file for the connected tenant and checks each pin. Unchanged pins pass.
2. **A change** fails that pin's row (or makes it `Investigate`, section 7.3). The row shows a table of
   pinned and current values, why the object matters, and how to accept the change.
3. **The admin accepts it**: `Update-MtTenantPin -Id MT.13xx.contoso.com` records the current value, with
   `PinnedAt` and `PinnedBy`. `Update-MtTenantPin -Discover` also adds anchors that are new since the last scan
   (a new CA policy, a new exclusion group) and retires pins whose object is gone, after the admin confirms.
4. **In CI** the pin file lives in the same repository as the config. Accepting is a commit, so a pull request
   is the review. A maester-action option that opens that pull request with the proposed update is a follow-up
   in that repository.

## 6. The pin file

```json
{
  "$schema": "https://maester.dev/schemas/maester-pins-1.0.json",
  "SchemaVersion": "1.0",
  "TenantId": "9f1c0000-0000-0000-0000-000000000000",
  "CreatedAt": "2026-11-09T04:12:00Z",
  "CreatedBy": "Maester 3.1.0",
  "Pins": [
    {
      "Kind": "entra.domain-federation",
      "Target": { "Id": "contoso.com", "DisplayName": "contoso.com" },
      "Source": "Discovered",
      "Severity": "High",
      "Reason": "contoso.com is federated with AD FS. A different issuer or signing certificate lets whoever holds it sign in as any user in the domain.",
      "PinnedAt": "2026-11-09T04:12:00Z",
      "PinnedBy": "admin@contoso.com",
      "Expected": {
        "issuerUri": "http://sts.contoso.com/adfs/services/trust",
        "passiveSignInUri": "https://sts.contoso.com/adfs/ls/",
        "signingCertificate": { "Thumbprint": "3F2A…91", "NotAfter": "2027-04-02" },
        "nextSigningCertificate": null,
        "federatedIdpMfaBehavior": "rejectMfaByFederatedIdp",
        "preferredAuthenticationProtocol": "wsFed",
        "promptLoginBehavior": "nativeSupport"
      }
    },
    {
      "Kind": "entra.ca-exclusion-group",
      "Target": { "Id": "4b9e…", "DisplayName": "CA-Exclude-BreakGlass" },
      "Source": "Discovered",
      "Severity": "High",
      "Reason": "Excluded from 14 enabled Conditional Access policies, including 'CA001 Require MFA for admins'. A new member skips all of them.",
      "PinnedAt": "2026-11-09T04:12:00Z",
      "PinnedBy": "admin@contoso.com",
      "Expected": {
        "groupTypes": [],
        "isAssignableToRole": true,
        "membershipRule": null,
        "members": [ { "Id": "a1…", "DisplayName": "bg-01@contoso.onmicrosoft.com" },
                     { "Id": "b2…", "DisplayName": "bg-02@contoso.onmicrosoft.com" } ],
        "owners": []
      }
    }
  ]
}
```

Rules:

- **One tenant per file, always named by tenant ID.** Maester looks for `maester-pins.<tenantId>.json` the way
  it looks for `maester-config.<tenantId>.json`: in the test folder and upwards. There is no unnamed default, so
  one tenant's pins can never be read for another. `Invoke-Maester -PinPath` points elsewhere. A file whose
  `TenantId` does not match the connection gives every pin family an `Error` row with reason
  `InvalidConfiguration`.
- **`Target.Id` is stable**: an object ID, or a domain name for domains. Renames do not break pins;
  `DisplayName` is only a label and is refreshed on update. The row ID is `<family ID>.<Target.Id>` with the
  instance grammar applied (`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`).
- **`Expected` holds normalised values** (section 7.2): sorted lists, certificates as thumbprint and expiry,
  script bodies as a SHA-256 hash, no timestamps.
- **`Source`** is `Discovered` (the scan), `Agent` (proposed by the skill and accepted) or `User` (added with
  `Add-MtTenantPin`). The scan never removes `Agent` or `User` pins on its own.
- **`Enabled: false`** keeps a pin in the file without checking it. Excluding a row with the usual
  `TestSettings` or `-ExcludeTestId` also works.
- **It is sensitive.** The file is a map of the tenant's soft spots: exclusion groups, break-glass IDs,
  trusted IP ranges. It holds no secrets, but it belongs in the same private repository as the config. Anyone
  who can change it can accept a change, so the docs say to protect the branch.

## 7. Pin kinds

A pin kind is the unit Maester ships. Each one has:

| Part | Job |
| --- | --- |
| Discover | Given the tenant, return the anchors of this kind, each with a severity and a reason (section 8). |
| Capture | Read one anchor's current state and normalise it. The same function feeds the scan and every run. |
| Compare | Compare `Expected` with the captured state and return the changes, each with a direction. |
| Guide | The family's `Test.<ID>.md`: what this kind is, why it matters, how to accept or undo a change. |

### 7.1 Comparison modes

| Mode | Fails when | Used for |
| --- | --- | --- |
| Exact | A listed property differs | Federation settings, a CA policy's conditions and controls, PIM rules |
| Set | Members are added or removed (each change is reported) | Role members, exclusion groups, federated domains, partner tenants, app credentials |
| Count | The count moves outside a tolerance (default: falls by more than 10%) | Groups a policy is *assigned* to, where joiners and leavers are normal |
| Exists | The object is deleted, or changes type (assigned to dynamic) | Every pin, implicitly |

A kind combines them. A CA *inclusion* group is Exists + Exact (`groupTypes`, `membershipRule`) + Count. A CA
*exclusion* group is Exists + Exact + Set on members, because every new member is a bypass. A Set on more than
1,000 members records the count and a hash of the sorted IDs instead of the list; the row then says that the
membership changed but cannot say how, and recommends making the group smaller.

### 7.2 Normalising and volatile properties

Each kind lists the properties it records, never "everything", so a new Graph property never breaks a pin.
Lists are sorted by ID. Timestamps such as `modifiedDateTime` are never recorded. Certificates are stored as
thumbprint plus `NotAfter`. Script content is stored as a SHA-256 hash.

The scan also captures every anchor twice, a few seconds apart, and drops any property whose two readings
differ. Values that change on their own (counters, replication lag) are found on the tenant itself instead of
in a hand-kept ignore list, and the first run after a scan passes.

### 7.3 Direction: weaker or stronger

A drift tool that fails on every change gets switched off. Each kind classifies each change:

| Direction | Result | Examples |
| --- | --- | --- |
| Weakens | `Failed` | Member added to an exclusion group; CA policy from `enabled` to `enabledForReportingButNotEnforced`; new federated domain; new credential on a privileged app; IP range added to a trusted location; AV exclusion added |
| Expected | `Passed` with a note | The signing certificate is now the pinned `nextSigningCertificate` (a planned rollover); a pinned credential expired and was removed |
| Strengthens or neutral | `Investigate` | Member removed from an exclusion group; new CA policy; MFA requirement added; partner tenant removed |
| Unknown | `Failed` | Anything the kind has no rule for |

`Investigate` keeps the change visible without counting it as a failure. Accepting clears it either way.

### 7.4 Where the code goes

Following the repository layout:

- **Readers** that other checks can reuse, such as `Get-MtDomainFederationConfiguration`, go in
  `powershell/internal/services/<service>/`. They call `Invoke-MtGraphRequest` and read through the session
  cache, like every check.
- **Discover, Capture and Compare** for each kind go in `powershell/internal/checks/maester/<service>/`, since
  only the pin families use them.
- **The shared pieces**, reading and validating the pin file and `Test-MtPin` (capture, compare, write the
  result), go in `powershell/internal/engine/`, since the engine supplies the instances.
- **A registry**, `powershell/assets/MaesterPinKinds.psd1`, lists each kind: `Key`, the three function names,
  the recorded properties, the modes and the direction rules. It is the same shape as the measures registry
  (`MaesterMeasures.psd1`).
- **The families** are ordinary native tests in `tests/maester/<service>/`, one per kind, with a new
  attribute property `PinKind` (section 13.1). Their `Service`, `License`, `Permission`, `Product`, `Feature`,
  `Severity` and `Mitre` are declared and reviewed against the rubric like any test.

A sketch of a family:

```powershell
function Test-MtPinnedDomainFederation {
    <#
    .SYNOPSIS
    Checks that each pinned federated domain keeps its federation settings.
    #>
    [MaesterTest(
        Id = 'MT.13xx',
        Title = 'Federated domains should keep their pinned federation settings.',
        PinKind = 'entra.domain-federation',
        Product = 'entra',
        Feature = 'hybrid-identity',
        Area = 'authentication',
        ResourceType = 'Domain',
        Severity = 'High',
        Mitre = 'T1484.002',
        Service = 'Graph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The pin to check, supplied by the engine from the pin file.
        $Instance
    )

    Test-MtPin -Instance $Instance   # capture, compare, write the result detail, return $true/$false/$null
}
```

The taxonomy keys in the sketch are placeholders; each family's values are chosen with the rubric when it is
written.

## 8. Deciding what is critical

The scan builds a dependency graph and pins what it reaches. This is what makes the pins specific to the
tenant and the reasons readable.

**Roots** are of two sorts:

- *Controls*: every enabled or report-only CA policy, the authentication methods policy, PIM settings for
  privileged roles, Intune compliance and endpoint security policies, Defender policies, mail flow protection.
- *Ways in*: federated domains, trusted certificate authorities, partner tenants (cross-tenant access, GDAP),
  privileged role members, service principals with high-impact permissions, emergency access accounts.

**Edges** are the references between objects:

```text
CA policy ──include/exclude──▶ user · group · role · named location · auth strength
CA policy ──requires compliant device──▶ Intune compliance policy ──assigned to──▶ group · filter
Intune security policy ──assigned to / excluded──▶ group ──dynamic rule──▶ (the rule itself)
Licensing group ──assigns──▶ SKU ──enables──▶ Entra ID P2 · Intune · Defender for each member
Privileged role ──held by──▶ user · group (role-assignable) · service principal
Service principal ──controlled by──▶ owners · credentials · federated identity credentials
Federated domain ──trusts──▶ issuer · signing certificate
```

**Severity** is the highest severity among the roots that reach the anchor. A group excluded from the
"require MFA for admins" policy is High; a group that only receives a Wi-Fi profile is not reached at all, so it
is not pinned. The reason string names the path ("Excluded from 'CA001 Require MFA for admins' and 3 other
policies"), so an admin can tell why every pin exists.

**Limits.** The scan pins only what it reaches from a root and only the properties the kind lists. Large
inclusion groups are pinned by count. A tenant with 300 CA policies gets 300 policy pins and the groups they
reference, which is the point; the report groups pin rows so they do not crowd out other checks (section 10).

**Emergency access accounts.** With `EmergencyAccessAccounts` set, those accounts are pinned. Without it, the
scan proposes as candidates the cloud-only users who hold Global Administrator and are excluded from every
enabled CA policy, and suggests setting `EmergencyAccessAccounts`. Candidates are written with
`Enabled: false` until the admin confirms them.

## 9. Catalogue of pin kinds

This is the research behind the first milestones. *Why* names what an attacker or a careless change gains.
Permissions marked † are not in `Get-MtGraphScope` today (decision 9).

### 9.1 Ways in (Entra ID)

| Kind | Discovers | Records | Why | Mode | Graph | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| `entra.federated-domains` | The tenant's domains | The set of federated domains, and each verified domain's authentication type | A new federated domain, or a managed domain turned federated, is a known persistence route: the attacker's IdP signs in as the domain's users (T1484.002) | Set | `GET /domains` | High |
| `entra.domain-federation` | Each federated domain | Issuer, sign-in and sign-out URIs, signing and next signing certificate, `federatedIdpMfaBehavior`, protocol, `promptLoginBehavior`, signed-request setting | A replaced signing certificate lets its holder forge tokens (T1606.002); `acceptIfMfaDoneByFederatedIdp` hands MFA to the IdP | Exact; rollover to the pinned next certificate is Expected | `GET /domains/{id}/federationConfiguration` | High |
| `entra.cba-trusted-cas` | Certificate-based authentication configurations | Each trusted CA's thumbprint, issuer, root flag, CRL URLs, and the CBA method's issuer and strength bindings | A rogue trusted CA lets someone sign in as any user with a certificate they issued (T1556) | Set + Exact | `GET /directory/publicKeyInfrastructure/certificateBasedAuthConfigurations` (beta) and the authentication methods policy | High |
| `entra.cross-tenant-partners` | Cross-tenant access default and partner settings | The partner tenants; per partner: inbound MFA and device trust, B2B direct connect, inbound user sync | Trusting another tenant's MFA or devices, or letting it sync users in, gives that tenant part of your access control (T1199) | Set + Exact | `GET /policies/crossTenantAccessPolicy/default`, `/partners` | High for trust or sync, else Medium |
| `entra.gdap-relationships` | Active delegated admin relationships | Partner tenant, roles granted, end date, auto-extend | Partner admins hold roles in your tenant; a new relationship or wider roles extends that (T1199) | Set + Exact | `GET /tenantRelationships/delegatedAdminRelationships` (`DelegatedAdminRelationship.Read.All` †) | High |
| `entra.directory-sync` | Hybrid tenants | `onPremisesSyncEnabled`, the sync feature flags (such as blocking soft match and cloud-object takeover through hard match), members of Directory Synchronization Accounts | Turning those flags off lets an on-premises account take over a cloud admin (T1556.007) | Exact + Set | `GET /organization`, `GET /directory/onPremisesSynchronization` | High |

### 9.2 Privilege (Entra ID and Azure)

| Kind | Discovers | Records | Why | Mode | Graph | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| `entra.privileged-role-members` | Roles with `isPrivileged`, Global Administrator first | Active and eligible principals, including through role-assignable groups | A new admin is the most direct escalation (T1098.003) | Set | `GET /roleManagement/directory/roleAssignments`, `roleEligibilitySchedules` | High for Global, Privileged Role and Privileged Authentication Administrator; Medium otherwise |
| `entra.pim-role-settings` | PIM rules of the same roles | MFA or auth strength on activation, approval and approvers, justification, maximum duration, expiry of eligible assignments | Dropping approval or MFA turns eligible admins into standing ones | Exact | `GET /policies/roleManagementPolicies` with `roleManagementPolicyAssignments` | High |
| `entra.privileged-apps` | Service principals with high-impact application permissions (such as `RoleManagement.ReadWrite.Directory`, `AppRoleAssignment.ReadWrite.All`, `Application.ReadWrite.All`, app-wide mail and files access) or a privileged role | The set of such apps; per app: those permissions, owners of the app and the service principal, credential key IDs, federated identity credentials (issuer and subject) | A new secret, owner or federated credential on an app that is already privileged is the quiet way to keep access (T1098.001) | Set | `GET /servicePrincipals/{id}/appRoleAssignments`, `/applications/{id}`, `/applications/{id}/federatedIdentityCredentials` | High |
| `entra.tenant-wide-consents` | Delegated grants with `consentType` `AllPrincipals` | Client, resource and scopes | Admin consent for all users to a delegated app (T1528) | Set | `GET /oauth2PermissionGrants` | Medium; High for mail, files or directory write scopes |
| `entra.emergency-access` | `EmergencyAccessAccounts`, or candidates (section 8) | Exists, enabled, cloud-only, still Global Administrator, excluded from every enabled CA policy, registered method IDs, restricted management unit if any | The way back in, and a prized target; a new method on it is a takeover | Exact + Set | `GET /users/{id}`, `/users/{id}/authentication/methods`, CA policies | High |
| `azure.root-owners` | Role assignments at `/`, management groups and subscriptions | Owner and User Access Administrator principals | Elevated access plus a root assignment controls every subscription (T1098.003) | Set | Azure Resource Manager role assignments | High |

### 9.3 Controls (Entra ID, Intune, Defender)

| Kind | Discovers | Records | Why | Mode | Graph | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| `entra.ca-policies` | Every CA policy | The set of policies; per policy: state, conditions, grant and session controls | Report-only or disabled policies, new exclusions and removed controls weaken it silently (T1556.009) | Set + Exact, with direction rules | `GET /identity/conditionalAccess/policies` | From what the policy does: High for MFA, legacy auth and admin policies |
| `entra.ca-exclusion-group` | Groups, users and roles excluded from an enabled policy | Type, dynamic rule, role-assignable flag, owners, members | A member added to an exclusion group skips every policy that excludes it | Exists + Exact + Set | `GET /groups/{id}`, `/groups/{id}/transitiveMembers`, `/owners` | Highest policy that excludes it |
| `entra.ca-inclusion-group` | Groups a policy targets, when it does not target all users | Type, dynamic rule, member count | An emptied group or an edited rule switches the policy off for those users | Exists + Exact + Count | Same | Highest policy that targets it |
| `entra.ca-named-locations` | Named locations a policy references | IP ranges, trusted flag, countries, unknown-country setting | An IP range added to a location that skips MFA opens that bypass to the range | Exact | `GET /identity/conditionalAccess/namedLocations` | High when used to skip a control |
| `entra.auth-methods` | The authentication methods policy and authentication strengths that CA references | Per method: state, include and exclude targets, key settings (FIDO2 AAGUID restrictions, Temporary Access Pass lifetime, SMS and voice); registration campaign; system-preferred MFA; strength combinations | Enabling a weak method, or excluding a group from a strong one, weakens every MFA prompt (T1556.006) | Exact | `GET /policies/authenticationMethodsPolicy`, `/policies/authenticationStrengthPolicies` | Medium; High for excluded groups and strengths used by CA |
| `entra.licensing-groups` | Groups that assign licences | SKUs and disabled plans, type, dynamic rule, member count | An edited rule or removed SKU takes Entra ID P2, Intune or Defender licences from users, and the features that check each user's licence stop for them | Exact + Count | `GET /groups?$filter=assignedLicenses/$count ne 0` | Medium |
| `intune.compliance-policies` | Compliance policies, all of them when a CA policy requires a compliant device | Settings, actions for non-compliance, assignments with include and exclude groups and filters | They define "compliant"; removing a requirement makes the CA policy weaker without touching it | Exact + Set | `GET /deviceManagement/deviceCompliancePolicies?$expand=assignments,scheduledActionsForRule` | High when CA depends on them |
| `intune.security-assignments` | Endpoint security policies, security baselines and app protection policies | Assignments: include and exclude groups and filters; the groups as in the CA kinds | An added exclusion or a removed assignment takes devices out of a control | Set, then the groups as above | `GET /deviceManagement/configurationPolicies?$expand=assignments`, `/deviceAppManagement/...` | Medium |
| `intune.assignment-filters` | Filters used by those assignments | Rule and platform | An edited filter changes which devices get a policy without editing the policy | Exact | `GET /deviceManagement/assignmentFilters` | Medium |
| `intune.scripts` | Platform scripts, macOS shell scripts and remediations | The set of scripts; per script: content hash, run-as account, signature check, assignments | A script assigned to all devices runs as SYSTEM everywhere: the route from one Intune admin to the whole fleet (T1072) | Set + Exact | `GET /deviceManagement/deviceManagementScripts`, `/deviceShellScripts`, `/deviceHealthScripts` (`DeviceManagementScripts.Read.All` †) | High |
| `intune.admin-controls` | Intune role assignments and multi-admin approval | Role members and scope tags; approval policies and what they cover | Multi-admin approval is what stops one admin wiping or scripting the fleet | Set + Exact | `GET /deviceManagement/roleAssignments`, `/deviceManagement/operationApprovalPolicies` | High |
| `defender.av-exclusions` | Antivirus and attack surface reduction exclusions in Intune endpoint security policies | Paths, processes, extensions; ASR per-rule and global exclusions | Each exclusion is a place malware can run unseen; adding one is a common first step (T1562.001) | Set | `GET /deviceManagement/configurationPolicies/{id}/settings` | High |

### 9.4 Mail and DNS (milestone 5)

| Kind | Records | Why | Mode | Source | Severity |
| --- | --- | --- | --- | --- | --- |
| `exchange.transport-rules` | Rules, state, priority, conditions and actions | Redirect, BCC or forward to outside, or SCL -1, is mail exfiltration or a filter bypass (T1114.003) | Set + Exact; external recipients and filter bypass weaken | `Get-TransportRule` | High |
| `exchange.connectors` | Inbound and outbound connectors: smart hosts, TLS, sender IPs and certificates, enhanced filtering | An inbound connector can make mail look internal or skip filtering; an outbound one can route mail through another host | Set + Exact | `Get-InboundConnector`, `Get-OutboundConnector` | High |
| `exchange.forwarding-and-journal` | Remote domains' auto-forward, outbound spam auto-forward mode, journal rules and recipients | Turning on forwarding or adding a journal recipient copies mail out | Exact + Set | `Get-RemoteDomain`, `Get-HostedOutboundSpamFilterPolicy`, `Get-JournalRule` | High |
| `exchange.mail-dns-records` | Per accepted domain: MX hosts, SPF, DMARC, DKIM selectors | A changed MX routes mail elsewhere; a new SPF include lets another sender pass as you | Exact | DNS lookups, as the existing SPF and DMARC checks do | High for MX, Medium otherwise |

### 9.5 Kinds only the admin or the agent can target

Some anchors matter because of what the business is, not because of a reference. Their kinds exist, but the
scan does not choose targets for them; the admin (`Add-MtTenantPin`) or the agent skill does.

| Kind | Records | Typical targets |
| --- | --- | --- |
| `entra.user-auth-methods` | Registered method IDs and types, default method | Executives, finance approvers, admins without PIM |
| `entra.app-credentials` | Owners, credential key IDs, federated identity credentials, permissions | Payroll and HR provisioning apps, SCIM connectors, customer-facing apps |
| `exchange.mailbox-access` | Full Access, Send As and Send on Behalf holders; inbox rules that forward or delete (T1114.002) | Executive and shared finance mailboxes |
| `entra.group-members` | Members and owners | Groups that grant access to a sensitive app or site |

Teams external access, SharePoint and OneDrive sharing, and Purview retention and DLP states are candidates
for later kinds.

## 10. Results and the report

Each pin is a row, `MT.13xx.<Target.Id>`, titled with the object's name ("Federated domain contoso.com should
keep its pinned federation settings"). A changed pin's detail looks like this:

```markdown
The federation settings of **contoso.com** changed since they were pinned on 2026-11-09 by admin@contoso.com.

| Setting | Pinned | Now | |
| --- | --- | --- | --- |
| signingCertificate | 3F2A…91 (expires 2027-04-02) | 77C0…1D (expires 2036-11-08) | Weakens |

**Why this is pinned:** contoso.com is federated with AD FS. A different issuer or signing certificate lets
whoever holds it sign in as any user in the domain.

**If you made this change**, accept it: `Update-MtTenantPin -Id MT.13xx.contoso.com`.
**If you did not**, treat it as an incident: restore the certificate and review sign-ins for contoso.com users.
```

The row also gets an additive `Pin` block in the result JSON (the next schema version; `main` writes 2.1): `Kind`, `TargetId`, `PinnedAt`,
`PinnedBy`, `Source`, `Changes` (property, pinned, current, direction) and, from milestone 3, `ChangedBy`.

Pin rows can number in the hundreds, almost all passing. To keep them from inflating the pass rate, the report
shows them in their own *Pinned configuration* section with its own count ("118 unchanged, 3 changed, 1 to
review"), leaves them out of the headline score, and lists changed pins at the top of the items that need
attention (decision 5).

## 11. Who changed it (milestone 3)

A changed pin is far more useful with a name and a time on it. For each changed pin, and only those, Maester
reads the audit records for the pin's target since `PinnedAt` (capped at the log's retention):

| Source | Query | Retention |
| --- | --- | --- |
| Entra audit log | `GET /auditLogs/directoryAudits?$filter=targetResources/any(t:t/id eq '{id}')` | 30 days with Entra ID P1, 7 days without |
| Intune audit events | `GET /deviceManagement/auditEvents` filtered by resource ID | 1 year |
| Azure activity log | Activity log for the scope | 90 days |
| Exchange admin audit | Purview audit search (asynchronous) | Later |

The row lists up to five records as facts: activity, time, actor (user or app), and the client the change came
from. With nothing found, it says so and gives the retention, so "no record" is not read as "nobody". The reads
go through the session cache like any check and use `AuditLog.Read.All` and `DeviceManagementApps.Read.All`,
which Maester already requests.

## 12. The agent skill

The admin's AI agent is good at what the dependency graph cannot see: which app runs payroll, who the
executives are, what a naming convention means, whether a group called *Finance-Approvers* deserves a pin. The
skill uses that judgement and nothing else.

Workflow of `maester-tenant-pins` (a `SKILL.md` for Claude Code, GitHub Copilot and other agents):

1. Run `New-MtTenantPin -WhatIf` (or `Update-MtTenantPin -Discover -WhatIf`) and read the candidates and the
   tenant summary. The deterministic scan always comes first.
2. Read more of the tenant, read-only, through Maester's connection or a Graph MCP server: titles, app names,
   group names, sign-in volume of apps, mailbox types.
3. Propose extra pins with the kinds in section 9.5, each with evidence ("*Workday Provisioning* has
   `User.ReadWrite.All` and syncs 4,200 users"). Never more than a reviewable handful at a time.
4. Write the accepted ones with `Add-MtTenantPin -Kind … -Target … -Reason …`, which validates the entry and
   marks it `Source: Agent`. The skill never edits the JSON by hand.
5. When nothing in the catalogue fits, write a custom test instead: `New-MtTest`, then check it with
   `Get-MtTest -Path` and `Invoke-MtTest -Path`, as the writing-tests guide describes.

Guardrails written into the skill: read-only on the tenant; no pin without the admin's yes; no secrets in the
file; every proposal cites what it read.

## 13. Changes to Maester

### 13.1 Engine

- **`PinKind` on `[MaesterTest]`.** A family with `PinKind` gets its instances from the pin file: one per
  enabled pin of that kind, `Id` from `Target.Id`, `Title` from the display name, `Severity` from the pin.
  It needs no `InstanceSource`.
- **No pin file, no rows.** Without a pin file for the tenant, pin families get `NotRun` with reason
  `NoPinFile`, not `Skipped`, so a tenant that does not use pins sees nothing new in its report. (A plain
  family would add one `Skipped NoInstances` row per kind to every run.)
- **Wrong tenant**: `Error` with `InvalidConfiguration` on every pin family (section 6).
- **Result schema 2.3**: the `Pin` block (section 10).
- The C# reader gains the property; the committed DLL is rebuilt.

### 13.2 Commands

All in `powershell/public/run/`, with full help:

| Command | Does |
| --- | --- |
| `New-MtTenantPin` | Scans and writes a new pin file. `-Kind` limits the kinds; `-WhatIf` returns the candidates without writing; refuses to overwrite an existing file. |
| `Update-MtTenantPin` | Re-records the pins named by `-Id` (row IDs or `-Kind`), or all changed pins with `-All` after showing them. `-Discover` adds new anchors and proposes retiring pins whose object is gone. Shows the diff and honours `-WhatIf`. |
| `Add-MtTenantPin` | Adds one pin of a kind for a target the admin or agent chose, with a reason. |
| `Get-MtTenantPin` | Lists the pins in the file, filtered by kind or ID. |

Checking pins needs no command of its own: `Invoke-Maester` runs them, and `Invoke-MtTest -Id MT.13xx` runs one
kind.

### 13.3 Repository

- One family per kind in `tests/maester/<service>/`, IDs reserved on
  [maester365/maester#697](https://github.com/maester365/maester/issues/697) before milestone 1.
- `powershell/assets/MaesterPinKinds.psd1`, and the file's schema at `website/public/schemas/maester-pins-1.0.json`
  beside the pack schemas. The four commands go in the manifest's `FunctionsToExport`.
- Unit tests: every registry kind has exactly one family with that `PinKind` and the reverse; each kind's
  Compare against fixture pairs, including each direction rule; normalisation is stable (capture the same
  fixture twice, no change); the pin file schema; wrong tenant; missing file.
- Docs: a *Tenant pins* page under `website/docs/` (what, how to scan, how to accept, CI, security of the file),
  each family's guide, and a link from MT.1060's guide.
- The agent skill's home is decision 10.

## 14. Noise, safety and limits

- **First run is clean.** The scan captures twice and drops volatile values (section 7.2); a run straight after
  the scan must have no changed pins, and the lab soak in milestone 1 checks this.
- **Steady state.** Target: fewer than one unexpected changed pin per week on a stable lab tenant over two
  weeks. Any kind that misses it gets its properties or direction rules fixed before it ships.
- **Read-only.** Pins never write to the tenant, and accepting writes only the local file.
- **Session cache.** All reads go through it; no kind bypasses it.
- **The pin file is trusted input.** Whoever can change it can accept a change. The docs recommend branch
  protection and review, the same as for the config. Signing the file is a later option.
- **Licences and connections.** A kind whose service is not connected, or whose licence or permission is
  missing, is skipped with the usual reason; the scan does not propose pins it cannot check.

## 15. Relationship to existing work

- **MT.1060 (drift folders)** stays for admins who supply their own JSON. Pins are the managed form: Maester
  picks, records and compares. Compare can reuse `Compare-MtJsonObject` for Exact properties.
- **`EmergencyAccessAccounts`** seeds the emergency access pins, and the scan suggests values for it.
- **Generic checks** stay the judge of "good". A pin on a weak setting still passes; the generic check fails.
- **`Compare-MtTestResult`** compares two runs' results. Pins compare the tenant with an approved state, so a
  change shows on the first run after it, even with no earlier result.
- **Microsoft's tenant configuration management APIs** (`/admin/configurationManagement`: monitors,
  baselines, drifts and snapshot jobs, `ConfigurationMonitoring.Read.All`, beta) watch the resources an admin
  configures. Maester could later read the drifts of monitors an admin created, as one more source for the
  report. It would not replace pins, which decide what to watch and explain why.

## 16. Milestones

| | Scope |
| --- | --- |
| M1 | Pin file and schema, `PinKind` and `NotRun NoPinFile`, shared `Test-MtPin`, `New-`, `Update-` and `Get-MtTenantPin`, kinds: federated domains, domain federation, CA policies, CA exclusion groups, CA named locations, privileged role members, emergency access. Unit tests and a lab soak. |
| M2 | The rest of 9.1 to 9.3: CBA, cross-tenant, GDAP, directory sync, PIM settings, privileged apps, consents, auth methods, CA inclusion groups, licensing groups, Intune and Defender kinds. |
| M3 | Who changed it (Entra and Intune audit), the `Pin` block and the report section. |
| M4 | `Add-MtTenantPin`, the kinds in 9.5, the agent skill, the docs page. |
| M5 | Exchange, DNS and Azure kinds; the maester-action pull-request flow (in that repository). |
| Later | Teams, SharePoint and Purview kinds; pin kinds shipped by packs; reading Microsoft's configuration drifts. |

## 17. Decisions for the owner

| # | Decision | Recommendation |
| --- | --- | --- |
| 1 | Name | **Tenant pins** ("pin", "accept"). "Baseline" already means three things in Maester (CIS and Intune baselines, MT.1060's `baseline.json`). Alternatives: watchlist, approved state. |
| 2 | Pin file and kind families, or generated test files, or AI-written tests | **Pin file and families**, with the AI as a proposal layer (section 4) |
| 3 | One family per kind, or one family per service | **Per kind**: own guide, gates, permissions, rubric review, and selection by ID; about 25 MT IDs |
| 4 | `PinKind` in the engine, or a plain `InstanceSource` | **`PinKind`**, so tenants without pins get no new rows |
| 5 | Pin rows in the headline score | **No**: own report section; changed pins listed under needs attention |
| 6 | A tightening change | **`Investigate`**, not `Failed` |
| 7 | File name and place | **`maester-pins.<tenantId>.json`** beside the config, found like the tenant config, never unnamed |
| 8 | Plain values or hashes in the file | **Plain values**, so a change can show from and to; hashes only for script bodies and memberships above 1,000 |
| 9 | `DeviceManagementScripts.Read.All` and `DelegatedAdminRelationship.Read.All` | **Add both to the default read scopes**: read-only, and scripts are among the highest-value pins |
| 10 | Where the user-facing agent skill lives | **A root `skills/` folder** in this repository, so skill installers can add it from GitHub; separate from the contributor skills in `.github/skills/` |
| 11 | Audit attribution in M3 | **Yes**, Entra and Intune first |
| 12 | Microsoft's configuration monitors | **Not now**; revisit as a reader once the API is generally available |
