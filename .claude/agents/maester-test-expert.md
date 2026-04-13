---
name: maester-test-expert
description: >-
  Write, validate, and document Maester security checks for Microsoft 365 tenants.
  Use when asked to create, edit, review, or debug a Maester Pester test file,
  its companion markdown documentation, or its tagging. Covers Graph API data retrieval,
  Add-MtTestResultDetail formatting, the tagging taxonomy (CIS, CISA, EIDSCA, ORCA, MT),
  helper function patterns, remediation guidance, Entra ID, Exchange, SharePoint, Teams,
  Defender, Conditional Access, and the validation checklist for new checks.
---

# Maester Test Expert

Create, edit, validate, and document Maester security checks -- the unit of work that assesses a Microsoft 365 tenant's security posture.

## Agent Selection

Use **maester-test-expert** as the primary agent for all normal workflows.

Specialized planner and issue-manager agents are optional workflow components and should generally stay in the background to avoid user confusion.

## When to Use This Skill

Activate this skill when the task involves any of the following:

- Creating a new Maester security check (test file + helper function + documentation)
- Editing or refactoring an existing check
- Adding or correcting tags on a test
- Writing or updating the companion markdown documentation for a check
- Writing or updating the website documentation page for a check
- Reviewing a check for correctness, tagging compliance, or documentation completeness
- Debugging a failing Maester test
- Understanding how Maester tests retrieve data from the Microsoft Graph API

**Do NOT use this skill for:**

- EIDSCA tests -- these are auto-generated from the `build/eidsca/` pipeline. Do not edit `tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1` by hand.
- ORCA tests -- these are auto-generated from the `build/orca/` pipeline. Do not edit files in `tests/orca/` by hand.
- General Pester questions unrelated to the Maester framework.

## Prerequisites

- The [Maester PowerShell module](https://www.powershellgallery.com/packages/Maester) installed.
- Familiarity with [Pester v5](https://pester.dev/) test structure (`Describe`, `Context`, `It`, `BeforeAll`, `BeforeDiscovery`).
- A working `Connect-Maester` session for local testing.
- Review the Maester [contribution guidelines](../../.github/CONTRIBUTING.md) before submitting changes.

## Anatomy of a Maester Check

A Maester check is a unit of work consisting of **up to four coordinated files**. Simple custom tests may use only one file; checks contributed to the project typically use all four.

### 1. Test File (`.Tests.ps1`)

**Location:** `tests/{Suite}/{Area}/` (e.g., `tests/Maester/Entra/`, `tests/CISA/entra/`, `tests/CIS/`)

The Pester test file that orchestrates execution. It calls a helper function, asserts the result, and carries tags for filtering.

### 2. Helper Function (`.ps1`)

**Location:** `powershell/public/{suite}/{area}/` (e.g., `powershell/public/cisa/entra/`, `powershell/public/maester/entra/`)

A PowerShell function that retrieves data (usually via Graph API), evaluates the tenant configuration, formats a result with `Add-MtTestResultDetail`, and returns `$true`, `$false`, or `$null`.

### 3. Companion Markdown (`.md`) -- Helper Documentation

**Location:** Same directory and same base name as the helper function (e.g., `powershell/public/cisa/entra/Test-MtCisaWeakFactor.md` alongside `Test-MtCisaWeakFactor.ps1`).

Provides the description, rationale, remediation steps, and reference links shown in the test report. Ends with a `%TestResult%` placeholder.

### 4. Website Documentation Page (`MT.XXXX.md`)

**Location:** `website/docs/tests/maester/` (e.g., `website/docs/tests/maester/MT.1001.md`)

The public documentation page on [maester.dev](https://maester.dev) with YAML frontmatter, a description, step-by-step remediation, and reference links.

### Simple Custom Tests (Single-File Pattern)

For quick custom checks (in the `tests/Custom/` directory), all logic and formatting can live in one `.Tests.ps1` file. No separate helper function or companion markdown is required. See the "Custom Test Template" below.

---

## Test File (.Tests.ps1)

### Naming Convention

| Suite | Pattern | Example |
|-------|---------|---------|
| Maester | `Test-{Feature}.Tests.ps1` or `Test-Mt{Feature}.Tests.ps1` | `Test-AppManagementPolicies.Tests.ps1` |
| CISA | `Test-MtCisa{Control}.Tests.ps1` | `Test-MtCisaWeakFactor.Tests.ps1` |
| CIS | `Test-MtCis{Control}.Tests.ps1` | `Test-MtCisGlobalAdminCount.Tests.ps1` |

The `.Tests.ps1` suffix is **mandatory** -- Pester uses it for automatic test discovery.

### Pester Structure

Every test file follows this pattern:

```powershell
Describe "{Suite/Area}" -Tag "{SuiteTag}", "{ProductAreaTag}" {
    It "{TestID}: {Description}. See https://maester.dev/docs/tests/{TestID}" -Tag "{TestID}" {
        $result = {HelperFunction}

        if ($null -ne $result) {
            $result | Should -Be $true -Because "{explanation of expected state}"
        }
    }
}
```

**Key rules:**

- The `Describe` block title identifies the suite and area (e.g., `"Maester/Entra"`, `"CISA"`, `"CIS"`).
- The `Describe` block `-Tag` carries the **test suite tag** (exactly one) and **product area tags** (1-3).
- The `It` block title starts with the **test ID** followed by a colon, then a human-readable description with a `See` link to the docs page.
- The `It` block `-Tag` carries only the **test ID** (e.g., `"MT.1024"`).
- The **null check pattern** (`if ($null -ne $result)`) ensures that when a helper returns `$null` (meaning it was skipped), the assertion is not evaluated and the test is reported as skipped rather than failed.

### Real Example -- Simple Maester Test

From `tests/Maester/Entra/Test-AppManagementPolicies.Tests.ps1`:

```powershell
Describe "Maester/Entra" -Tag "Maester", "App" {
    It "MT.1002: App management restrictions on applications and service principals is configured and enabled. See https://maester.dev/docs/tests/MT.1002" -Tag "MT.1002" {

        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because "an app policy for workload identities should be defined to enforce strong credentials instead of passwords and a maximum expiry period (e.g. credential should be renewed every six months)"
    }
}
```

### Real Example -- CISA Test with Null Check

From `tests/CISA/entra/Test-MtCisaWeakFactor.Tests.ps1`:

```powershell
Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.5", "CISA.MS.AAD.3.5", "CISA", "Entra ID P1" {
    It "CISA.MS.AAD.3.5: The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled." {
        $result = Test-MtCisaWeakFactor

        if ($null -ne $result) {
            $result | Should -Be $true -Because "all weak authentication methods are disabled."
        }
    }
}
```

### Real Example -- CIS Test

From `tests/CIS/Test-MtCisGlobalAdminCount.Tests.ps1`:

```powershell
Describe "CIS" -Tag "CIS.M365.1.1.3", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "CIS M365 v5.0.0" {
    It "CIS.M365.1.1.3: Ensure that between two and four global admins are designated" {

        $result = Test-MtCisGlobalAdminCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "only 2-4 Global Administrators exist"
        }
    }
}
```

### Advanced Pattern -- Parameterized Tests with BeforeDiscovery

Some checks generate dynamic tests from data discovered at parse time. This pattern is used for health issues, per-user evaluations, and similar scenarios.

```powershell
BeforeDiscovery {
    $Items = Invoke-MtGraphRequest -RelativeUri "some/endpoint" -ApiVersion beta
    # Process and group items as needed
}

Describe "Maester/Area" -Tag "Maester", "ProductArea" -ForEach $Items {
    It "MT.XXXX: {Description} - $($_.Name)" -Tag "MT.XXXX" {
        $_.status | Should -Be "healthy" -Because "all items should be in a healthy state"
    }
}
```

### Advanced Pattern -- Conditional Execution (License/Connection Gating)

Tests that require specific licenses or service connections use `-Skip` on the `It` block:

```powershell
BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product 'EntraID'
}

Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXXX: {Description}" -Tag "MT.XXXX" -Skip:($EntraIDPlan -eq "Free") {
        # Test logic -- only runs if Entra ID P1 or P2 is available
    }
}
```

---

## Helper Function (.ps1)

### Naming Convention

- **Maester suite:** `Test-Mt{Feature}.ps1` (e.g., `Test-MtAppManagementPolicyEnabled.ps1`)
- **CISA suite:** `Test-MtCisa{Control}.ps1` (e.g., `Test-MtCisaWeakFactor.ps1`)
- **CIS suite:** `Test-MtCis{Control}.ps1` (e.g., `Test-MtCisGlobalAdminCount.ps1`)

### Directory Placement

| Suite | Directory |
|-------|-----------|
| Maester | `powershell/public/maester/{area}/` (e.g., `entra/`, `exchange/`, `teams/`, `azure/`) |
| CISA | `powershell/public/cisa/{area}/` (e.g., `entra/`, `exchange/`, `spo/`) |
| CIS | `powershell/public/cis/` |

### Structure Template

```powershell
function Test-Mt{Name} {
    <#
    .SYNOPSIS
    {One-line summary of what the check verifies}

    .DESCRIPTION
    {Detailed description of the security control being evaluated}

    .EXAMPLE
    Test-Mt{Name}

    Returns true if {condition is met}

    .LINK
    https://maester.dev/docs/commands/Test-Mt{Name}
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # 1. Connection check
    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    # 2. License check (if applicable)
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if ($EntraIDPlan -eq "Free") {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        # 3. Retrieve data
        $data = Invoke-MtGraphRequest -RelativeUri "endpoint"

        # 4. Evaluate configuration
        $testResult = ($data.someProperty -eq $expectedValue)

        # 5. Format result markdown
        if ($testResult) {
            $testResultMarkdown = "Well done. {Positive outcome description.}"
        } else {
            $testResultMarkdown = "{Negative outcome description with actionable detail.}"
        }

        # 6. Report result (omit -Description to use companion .md file)
        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
```

### Key Patterns

#### Connection Checks

Always verify the required service connection before making API calls:

```powershell
# Microsoft Graph
if (!(Test-MtConnection Graph)) {
    Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
    return $null
}

# Microsoft Teams
if (!(Test-MtConnection Teams)) {
    Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
    return $null
}

# Application permissions not supported
if (((Get-MgContext).AuthType) -ne "Delegated") {
    Add-MtTestResultDetail -SkippedBecause 'NotSupportedAppPermission'
    return $null
}
```

#### Data Retrieval with Invoke-MtGraphRequest

**Always prefer `Invoke-MtGraphRequest` over `Invoke-MgGraphRequest` or `Get-Mg*` cmdlets.** It provides:

- **Built-in caching** -- reduces API calls when multiple tests query the same endpoint.
- **Automatic pagination** -- no need for `-All`.
- **ConsistencyLevel header** -- included by default for read-only calls.
- **Batching** -- pass an array of IDs via `-UniqueId` for automatic batch optimization.
- **Named parameters** -- `Select`, `Filter`, `QueryParameters` for cleaner code.

```powershell
# Simple query
$policies = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

# With filter and select
$users = Invoke-MtGraphRequest -RelativeUri "users" -Filter "userType eq 'Member'" -Select id, displayName

# Batch by IDs
$users = Invoke-MtGraphRequest -RelativeUri "users" -UniqueId $userIds -Select id, displayName, onPremisesSyncEnabled

# Complex query with splatting
$policySplat = @{
    ApiVersion      = "beta"
    RelativeUri     = "policies/roleManagementPolicyAssignments"
    Filter          = "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($role.id)'"
    QueryParameters = @{
        expand = "policy(expand=rules)"
    }
}
$policy = Invoke-MtGraphRequest @policySplat
```

#### Result Formatting

Use `Add-MtTestResultDetail` to provide rich test output:

```powershell
# Basic result text (companion .md provides the description)
Add-MtTestResultDetail -Result $resultMarkdown

# With description (when no companion .md exists)
Add-MtTestResultDetail -Description "What the test checks" -Result "The outcome"

# With Graph objects (creates deep links to admin portal)
Add-MtTestResultDetail -Result "Found issues:`n`n%TestResult%" -GraphObjects $failingPolicies -GraphObjectType ConditionalAccess

# Marking a result for manual review
Add-MtTestResultDetail -Description $description -Result $result -Investigate

# Custom skipped reason
Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "All alerts have been suppressed"
```

Supported `-GraphObjectType` values: `Users`, `Groups`, `Devices`, `ConditionalAccess`, `AuthenticationMethod`, `AuthorizationPolicy`, `ConsentPolicy`, `Domains`, `IdentityProtection`, `UserRole`.

When using `-GraphObjects`, the `-Result` string **must** include `%TestResult%` at the position where the object list will be inserted.

#### Error Handling

**Critical rule:** Wrap the main logic in `try`/`catch`. In the `catch` block, call `Add-MtTestResultDetail -SkippedBecause Error` and return `$null`.

```powershell
try {
    # Main test logic here
} catch {
    Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    return $null
}
```

**Do NOT call `Add-MtTestResultDetail -SkippedBecause` inside the `try` block.** This causes the test to be reported as errored instead of skipped. Close the `try` block first, then call the skip method, then start a new `try` block if needed.

#### Module Registration

After creating a new helper function, add the function name to the `FunctionsToExport` array in `powershell/Maester.psd1`.

---

## Companion Markdown (.md) -- Helper Documentation

This file provides the description shown in the Maester test report. It has **no YAML frontmatter**.

### Location and Naming

Place the `.md` file in the **same directory** as the helper function, with the **same base name**:

```
powershell/public/cisa/entra/Test-MtCisaWeakFactor.ps1   ← helper function
powershell/public/cisa/entra/Test-MtCisaWeakFactor.md    ← companion doc
```

### Template

```markdown
{One-line summary of what the check verifies.}

{Rationale: explain WHY this configuration matters for security.}

#### Remediation action:

1. In **Entra ID**, navigate to **{Section}** > **[{Page Name}]({direct admin portal URL})**.
2. {Step-by-step instructions to fix the issue.}
3. Click **Save**.

#### Related links

* [{Admin portal link description}]({URL})
* [{Benchmark or baseline reference}]({URL})

<!--- Results --->
%TestResult%
```

### Key Rules

- The `%TestResult%` placeholder at the end is **mandatory**. It is replaced at runtime with the formatted test output.
- The `<!--- Results --->` HTML comment before the placeholder is conventional but optional.
- Omit the `-Description` parameter when calling `Add-MtTestResultDetail` in the helper so that the companion `.md` content is used as the description automatically.
- Include direct links to the relevant admin portal blade (Entra, Exchange, SharePoint, etc.) so the reader can navigate directly to the configuration.

### Real Example

From `powershell/public/cisa/entra/Test-MtCisaWeakFactor.md`:

```markdown
The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled.

Rationale: SMS, voice call, and email OTP are the weakest authenticators. This policy forces users to use stronger MFA methods.

#### Remediation action:

1. In **Entra ID**, click **Security** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity)**
2. Click on the **SMS**, **Voice Call**, and **Email OTP** authentication methods and disable each of them.

#### Related links

* [Entra admin portal - Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity)
* [CISA Strong Authentication & Secure Registration - MS.AAD.3.5v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad35v1)

<!--- Results --->
%TestResult%
```

---

## Website Documentation Page (MT.XXXX.md)

This is the public documentation page hosted on [maester.dev](https://maester.dev).

### Location

`website/docs/tests/maester/MT.XXXX.md` (replace `XXXX` with the test ID number).

### Template

```markdown
---
title: MT.XXXX - {Short title}
description: {One-line description}
slug: /tests/MT.XXXX
sidebar_class_name: hidden
---

# {Short title}

## Description

{Detailed description of what the check verifies and why it matters.}

## How to fix

{Step-by-step remediation instructions.}

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a {minimum required role}.
2. Browse to **{Section}** > **{Page}**.
3. {Specific configuration steps.}
4. Select **Save**.

## Learn more

- [{Reference title}]({URL})
- [{Admin portal link}]({URL})
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | `MT.XXXX - {Short title}` |
| `description` | Yes | One-line description of the check |
| `slug` | Yes | `/tests/MT.XXXX` |
| `sidebar_class_name` | Yes | Always `hidden` |

### Real Example

From `website/docs/tests/maester/MT.1001.md`:

```markdown
---
title: MT.1001 - At least one Conditional Access policy is configured with device compliance
description: Device compliance conditional access policy can be used to require devices to be compliant with the tenant's security configuration.
slug: /tests/MT.1001
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured with device compliance

## Description

Device compliance conditional access policy can be used to require devices to be compliant with the tenant's security configuration.

## How to fix

Create a conditional access policy that requires devices to have device compliance.

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Conditional Access Administrator.
2. Browse to **Protection** > **Conditional Access** > **Policies**.
3. Select **New policy**.
4. Give your policy a name.
5. Under **Assignments**, select **Users or workload identities**.
    - Under **Target resources** > **Resources (formerly cloud apps)** > **Include**, select **All resources (formerly 'All cloud apps')**.
6. Under **Access controls** > **Grant**.
    - Select **Require device to be marked as compliant** and **Require Microsoft Entra hybrid joined device**
    - **For multiple controls** select **Require one of the selected controls**.
    - Select **Select**
8. Confirm your settings and set **Enable policy** to **Enable**
9. Select **Create** to create to enable your policy.

## Related links
- [Entra admin center - Conditional Access | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
```

---

## Tagging Taxonomy

Tags identify, group, and filter tests during execution. Follow these rules strictly.

### Three Tag Categories

#### 1. Test Suite (Required -- Exactly One)

Identifies which benchmark or baseline the test aligns with. This tag goes in the **`Describe` block**.

| Suite | Tag Format | Examples |
|-------|-----------|----------|
| Maester | `Maester` | `"Maester"` |
| CISA | `CISA` + control ID tags | `"CISA"`, `"MS.AAD.3.5"`, `"CISA.MS.AAD.3.5"` |
| CIS | `CIS` + benchmark tags | `"CIS"`, `"CIS.M365.1.1.3"`, `"CIS M365 v5.0.0"` |
| EIDSCA | `EIDSCA` + control ID | `"EIDSCA"`, `"EIDSCA.AP01"` |
| ORCA | `ORCA` + control ID | `"ORCA"`, `"ORCA.100"` |

#### 2. Product Area (Required -- 1 to 3 tags)

Identifies which Microsoft 365 products or services are tested. These tags also go in the **`Describe` block**.

| Valid Product Area Tags |
|------------------------|
| `Azure` |
| `Defender XDR` |
| `Entra` |
| `Exchange` |
| `Microsoft 365` |
| `SharePoint` |
| `Teams` |

#### 3. Practice / Capability (Optional -- Use Sparingly)

Denotes a specific security practice. Only add when it provides significant categorization value. Avoid creating single-use tags.

| Valid Practice Tags |
|--------------------|
| `Authentication` |
| `CA` (Conditional Access) |
| `DLP` (Data Loss Prevention) |
| `XSPM` (Extended Security Posture Management) |
| `Hybrid Identity` |
| `PAM` (Privileged Access Management) |
| `PIM` (Privileged Identity Management) |

### Special Tags

| Tag | Purpose |
|-----|---------|
| `LongRunning` | Marks tests that may take significant time in large tenants. Excluded by default; included via `Invoke-Maester -IncludeLongRunning`. |
| `Preview` | Marks tests that depend on preview APIs or are still being validated. Excluded by default; included via `Invoke-Maester -IncludePreview`. |
| `Severity:{Level}` | Optionally set on `It` blocks. Valid levels: `Critical`, `High`, `Medium`, `Low`, `Info`, and `Investigate`. The preferred location to set these is in `maester-config.json`. |
| `License` | Used to tag license-related tests. |

### Deprecated Tags -- Do NOT Use

| Deprecated Tag | Replacement |
|---------------|-------------|
| `All` | Removed. Use `Invoke-Maester -IncludePreview` instead. |
| `Full` | Removed. Use `Invoke-Maester -IncludeLongRunning` instead. |

### Tag Placement Summary

```powershell
Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
#                              ↑ Suite     ↑ Product  ↑ Practice (optional)
    It "MT.1001: Description" -Tag "MT.1001", "Severity:High" {
    #                               ↑ Test ID    ↑ Severity (optional)
    }
}
```

---

## Step-by-Step Workflow: Creating a New Check

Follow these steps to create a complete Maester check contributed to the project.

### Step 1: Reserve a Test ID

Check [GitHub issue #697](https://github.com/maester365/maester/issues/697) to see which test numbers have been used. Comment on the issue to reserve your ID (e.g., `MT.1123`).

### Step 2: Determine File Locations

Based on the suite and product area:

- **Test file:** `tests/Maester/{Area}/Test-Mt{Feature}.Tests.ps1`
- **Helper function:** `powershell/public/maester/{area}/Test-Mt{Feature}.ps1`
- **Companion doc:** `powershell/public/maester/{area}/Test-Mt{Feature}.md`
- **Website doc:** `website/docs/tests/maester/MT.XXXX.md`

### Step 3: Write the Helper Function

Create the `.ps1` file following the helper function template above. Ensure:

1. Connection check is first.
2. License check follows (if the check requires P1/P2).
3. Data retrieval uses `Invoke-MtGraphRequest`.
4. Result formatting uses `Add-MtTestResultDetail`.
5. Error handling wraps everything in `try`/`catch`.
6. Function returns `$true`, `$false`, or `$null`.

### Step 4: Write the Companion Markdown

Create the `.md` file alongside the helper. Include:

1. One-line summary.
2. Rationale.
3. Numbered remediation steps with admin portal links.
4. Related reference links.
5. The `%TestResult%` placeholder at the end.

### Step 5: Write the Test File

Create the `.Tests.ps1` file following the test file template. Ensure:

1. `Describe` block has exactly one suite tag and 1-3 product area tags.
2. `It` block title starts with the test ID and includes a `See` link to the docs page.
3. `It` block `-Tag` includes the test ID.
4. The null check pattern wraps the assertion.
5. The `-Because` message explains the expected state clearly.

### Step 6: Write the Website Documentation

Create the `MT.XXXX.md` file with YAML frontmatter and the standard sections (Description, How to fix, Learn more).

### Step 7: Register the Function

Add the helper function name to the `FunctionsToExport` array in `powershell/Maester.psd1`.

### Step 8: Validate

Run the validation checklist below.

---

## Custom Test Template (Single-File Pattern)

For checks that live in `tests/Custom/` and do not need a separate helper function:

```powershell
Describe "ContosoEntraConfig" -Tag "Entra" {
    It "CT.0001: {Description}" -Tag "CT.0001", "Severity:Medium" {

        try {
            # Retrieve data
            $data = Invoke-MtGraphRequest -RelativeUri "endpoint"

            # Evaluate
            $failing = $data | Where-Object { $_.Property -ne $ExpectedValue }

            # Format results
            $testDescription = "Checks if {what is being checked}."
            if ($failing.Count -gt 0) {
                $result = "Found $($failing.Count) items not meeting the requirement.`n`n%TestResult%"
                Add-MtTestResultDetail -Description $testDescription -Result $result -GraphObjects $failing -GraphObjectType ConditionalAccess
            } else {
                Add-MtTestResultDetail -Description $testDescription -Result "Well done. All items meet the requirement."
            }

            $failing.Count | Should -Be 0 -Because "{explanation}"
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    }
}
```

---

## Validation Checklist

Before submitting a new or updated check, verify every item:

### Test Logic
- [ ] Helper function returns `$true` when the check passes, `$false` when it fails, and `$null` when it is skipped.
- [ ] Connection check (`Test-MtConnection`) is the first operation in the helper.
- [ ] License check (`Get-MtLicenseInformation`) is present if the check requires Entra ID P1/P2.
- [ ] Data retrieval uses `Invoke-MtGraphRequest` (not `Invoke-MgGraphRequest` or `Get-Mg*` cmdlets) for caching benefits.
- [ ] No hardcoded values -- GUIDs, tenant IDs, or user-specific data must be parameterized or discovered.
- [ ] Error handling: main logic is wrapped in `try`/`catch`; catch block calls `Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_` and returns `$null`.
- [ ] No `Add-MtTestResultDetail -SkippedBecause` calls inside a `try` block.

### Test File
- [ ] File name ends with `.Tests.ps1`.
- [ ] `Describe` block has exactly one test suite tag.
- [ ] `Describe` block has 1-3 product area tags.
- [ ] `It` block title starts with the test ID followed by a colon.
- [ ] `It` block `-Tag` includes the test ID.
- [ ] Null check pattern wraps the `Should` assertion.
- [ ] `-Because` message is clear, specific, and actionable.

### Tags
- [ ] No deprecated tags (`All`, `Full`).
- [ ] Practice/capability tags are used sparingly (0-1 per test in most cases).
- [ ] `LongRunning` tag is applied if the test may be slow in large tenants.
- [ ] `Preview` tag is applied if the test depends on preview/beta APIs.
- [ ] Tags are consistent with the [tag taxonomy](../../website/docs/tests/tags/readme.md).

### Documentation
- [ ] Companion `.md` file exists alongside the helper function.
- [ ] Companion `.md` ends with `%TestResult%`.
- [ ] Companion `.md` includes remediation steps with admin portal links.
- [ ] Website doc `MT.XXXX.md` exists with correct YAML frontmatter.
- [ ] Website doc includes Description, How to fix, and Learn more sections.
- [ ] Test ID is consistent across the test file name/tags, companion doc, and website doc.

### Output Messages
- [ ] Pass message starts with "Well done." and describes the positive outcome.
- [ ] Fail message clearly states what is wrong and what needs to change.
- [ ] Markdown tables use proper formatting (headers, separators, rows).
- [ ] Admin portal deep links are included where applicable.

### Code Style
- [ ] One True Brace Style (OTBS) -- opening brace on the same line.
- [ ] Pascal Case for variables and function names.
- [ ] Full cmdlet names -- no aliases (e.g., `Where-Object` not `?` or `where`).
- [ ] Comment-based help is inside the function block with `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, and `.LINK`.
- [ ] `[CmdletBinding()]` and `[OutputType([bool])]` are declared.
- [ ] File encoding is UTF-8 with BOM (UTF8BOM).

### Pre-Pull Request
- [ ] Helper function name is added to `FunctionsToExport` in `powershell/Maester.psd1`.
- [ ] Local tests pass: run `powershell/tests/pester.ps1`.
- [ ] PSScriptAnalyzer shows no warnings.
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/).

---

## Common Mistakes

| Mistake | Why It Matters | Fix |
|---------|---------------|-----|
| Using `Invoke-MgGraphRequest` or `Get-Mg*` cmdlets instead of `Invoke-MtGraphRequest` | Bypasses caching -- tests become slow and make redundant API calls | Replace with `Invoke-MtGraphRequest` |
| Missing the null check pattern around `Should` | A skipped test (`$null`) is reported as a failure instead | Wrap assertion in `if ($null -ne $result) { ... }` |
| Calling `Add-MtTestResultDetail -SkippedBecause` inside a `try` block | Test is reported as errored instead of skipped | Move the call outside the `try` block |
| Hardcoded GUIDs or tenant-specific values | Test fails in every other tenant | Discover values dynamically via Graph API |
| Using deprecated tags `All` or `Full` | These tags no longer work; tests will not be properly filtered | Use `LongRunning` or `Preview` tags; users run them via `-IncludeLongRunning` or `-IncludePreview` switches |
| Over-tagging with many practice/capability tags | Increases noise; makes tag filtering less useful | Limit to 1 practice tag maximum per test, only when it adds clear value |
| Creating a test without its companion `.md` | Test report shows no description or remediation guidance | Always create the `.md` file alongside the helper |
| Creating a helper without adding it to `FunctionsToExport` | Function is not exported from the module and cannot be called | Add to the array in `powershell/Maester.psd1` |
| Missing connection or license checks | Test throws an unhandled error when the service is not connected | Add `Test-MtConnection` and `Get-MtLicenseInformation` checks before any API calls |
| Omitting the `%TestResult%` placeholder in the companion `.md` | Runtime results are not inserted into the test report | Add `%TestResult%` at the end of the `.md` file |
| Wrong Graph API scopes or permissions | Test fails at runtime with 403 errors | Verify required scopes are in `Get-MtGraphScope` and document any special permissions |
| Manually editing auto-generated EIDSCA or ORCA tests | Changes are overwritten by the next generation run | Modify the generation pipeline in `build/eidsca/` or `build/orca/` instead |

---

## Reference Examples

These existing files demonstrate the patterns described in this skill. Read them for concrete implementation guidance.

### Complete CISA Check (Recommended Starting Point)
- **Test file:** `tests/CISA/entra/Test-MtCisaWeakFactor.Tests.ps1`
- **Helper function:** `powershell/public/cisa/entra/Test-MtCisaWeakFactor.ps1`
- **Companion doc:** `powershell/public/cisa/entra/Test-MtCisaWeakFactor.md`

### Simple Maester Check
- **Test file:** `tests/Maester/Entra/Test-AppManagementPolicies.Tests.ps1`
- **Helper function:** `powershell/public/maester/entra/Test-MtAppManagementPolicyEnabled.ps1`
- **Companion doc:** `powershell/public/maester/entra/Test-MtAppManagementPolicyEnabled.md`

### Website Documentation
- `website/docs/tests/maester/MT.1001.md` -- Conditional Access device compliance
- `website/docs/tests/maester/MT.1024.md` -- Entra recommendations
- `website/docs/tests/maester/MT.1059.md` -- Defender for Identity health issues

### Parameterized Test (Dynamic Test Generation)
- `tests/Maester/Defender/Test-MtMdiHealthIssues.Tests.ps1` -- Uses `BeforeDiscovery` and `-ForEach`

### Custom Test Authoring Guide
- `website/docs/writing-tests/index.mdx` -- Getting started with custom tests
- `website/docs/writing-tests/formatting-test-results.md` -- `Add-MtTestResultDetail` patterns
- `website/docs/writing-tests/advanced-concepts.md` -- `Invoke-MtGraphRequest`, split-file pattern, error handling

### Tagging Reference
- `website/docs/tests/tags/readme.md` -- Complete tag taxonomy with counts and usage recommendations

### Contributing Guidelines
- `.github/CONTRIBUTING.md` -- Coding conventions, pre-PR checklist, PowerShell style requirements

---

## Troubleshooting

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| Test shows as "Error" instead of "Skipped" | `Add-MtTestResultDetail -SkippedBecause` was called inside a `try` block | Move the call outside the `try` block |
| Test always fails with `$null` assertion error | Missing null check pattern around `Should` | Wrap assertion: `if ($null -ne $result) { $result \| Should ... }` |
| Test runs but report shows no description | Companion `.md` file is missing or `-Description` was not provided | Create the companion `.md` or pass `-Description` to `Add-MtTestResultDetail` |
| `%TestResult%` appears literally in the report | The placeholder was not included in the `-Result` string when using `-GraphObjects` | Ensure the `-Result` string contains `%TestResult%` |
| 403 Forbidden from Graph API | Missing permissions/scopes | Check `Get-MtGraphScope` for required scopes; add new scopes if needed |
| Test is never discovered by Pester | File name does not end with `.Tests.ps1` | Rename to include the `.Tests.ps1` suffix |
| Helper function not found at runtime | Function not added to `FunctionsToExport` in `powershell/Maester.psd1` | Add the function name to the manifest |
| Test runs in local dev but is excluded in CI | Test is tagged `LongRunning` or `Preview` and CI does not use `-IncludeLongRunning`/`-IncludePreview` | Verify tags are intentional; adjust CI invocation if needed |
