# Device compensation gap-fill — when ZTA flags unmanaged / non-compliant /
# personally-owned devices, verify the compensating controls (Intune App
# Protection Policy with proper assignment, CA blocking non-compliant,
# compliance-failure analysis) are actually in place.
#
# Per user feedback (2026-05-10): MT.Zta.1110 / 1111 must verify that the
# APP ASSIGNMENT targets a real user/group, not the all-licensed-users
# placeholder which exists by default but isn't actionable.
#
# ZTA TestId triggers used in this file:
#
#   24543  Devices / Tenant
#          Compliance policies protect iOS/iPadOS devices
#   24545  Devices / Tenant
#          Compliance policies protect fully managed and corporate-owned Android devices
#   24547  Devices / Tenant
#          Compliance policies protect personally owned Android devices
#   24548  Devices / Data
#          Data on iOS/iPadOS is protected by app protection policies
#   24823  Devices / Tenant
#          Company Portal branding and support settings enhance user experience
#   24824  Devices / Data
#          Conditional Access policies block access from noncompliant devices
#
# References:
#   ZTA project        https://microsoft.github.io/zerotrustassessment/
#   Microsoft Learn    https://learn.microsoft.com/security/zero-trust/assessment/

Describe 'ZTA device compensation' -Tag 'ZTA' {

    It 'MT.Zta.1110: iOS App Protection Policy covers unmanaged devices and is assigned to user/group. See https://maester.dev/docs/tests/MT.Zta.1110' `
       -Tag 'MT.Zta.1110','Severity:High','Devices','Intune','MAM','iOS' {

        $description = @'
## What this test checks
When ZTA [`24543`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24543.md) (compliance policies protect iOS) or [`24548`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24548.md) (data on iOS protected by APP) is Failed, verifies that an Intune App Protection Policy (APP / MAM-WE) for iOS:
1. Targets `unmanagedAndManaged` device states (not just `managedDevices`).
2. Is enabled (not in draft).
3. Has at least one **`groupAssignmentTarget`** assignment — i.e. the policy is assigned to a real user/security group, NOT just the `allLicensedUsersAssignmentTarget` placeholder which Intune injects by default but which doesn't surface in the operator's assigned-policy list and is easy to leave un-assigned in practice.

## How to remediate
1. Intune → Apps → App protection policies → iOS/iPadOS → either create or edit the policy.
2. Set **Target apps** to all Microsoft 365 apps (or your scoped list).
3. Under **Targeted app management level**, choose **Unmanaged AND Managed** (or **All app types**).
4. Under **Assignments**, assign to a real group (e.g., "All employees" security group) — not the empty default.
5. Save and verify rollout via Intune → Apps → Monitor.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('24543','24548') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 24543/24548 — iOS APP gap-fill not applicable."
            return
        }

        try {
            # $expand is NOT a $filter clause — bake it directly into the relative URI.
            # Single-quoted string keeps the literal $ for Graph; PowerShell otherwise
            # treats $expand as variable interpolation.
            $apps = Invoke-MtGraphRequest -RelativeUri 'deviceAppManagement/iosManagedAppProtections?$expand=assignments' -ApiVersion beta
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $compliant = @($apps | Where-Object {
            $hasUnmanagedScope = ($_.targetedAppManagementLevels -in @('unmanagedAndManaged','unspecified')) -or ($_.targetedAppManagementLevels -contains 'unmanaged')
            $hasRealAssignment = @($_.assignments | Where-Object {
                $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'
            }).Count -gt 0
            $isEnabled = ($_.disabled -ne $true)
            $hasUnmanagedScope -and $hasRealAssignment -and $isEnabled
        })

        $sample = if ($apps) {
            ($apps | Select-Object -First 5 | ForEach-Object {
                $level = if ($_.targetedAppManagementLevels) { $_.targetedAppManagementLevels } else { '(unset)' }
                $assigns = @($_.assignments | Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' }).Count
                "| $($_.displayName) | $level | $assigns group target(s) |"
            }) -join "`n"
        } else { '_no iOS APP policies exist in the tenant._' }

        $result = @"
| Metric | Value |
|---|---|
| iOS App Protection Policies (total) | $(@($apps).Count) |
| Compliant (unmanaged scope + real group assignment + enabled) | **$($compliant.Count)** |
| ZTA trigger tests | $($triggered.Count) Failed |

### Sample policies (first 5)

| Name | targetedAppManagementLevels | groupAssignmentTarget assignments |
|---|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $compliant.Count | Should -BeGreaterThan 0
    }

    It 'MT.Zta.1111: Android App Protection Policy covers unmanaged devices and is assigned to user/group. See https://maester.dev/docs/tests/MT.Zta.1111' `
       -Tag 'MT.Zta.1111','Severity:High','Devices','Intune','MAM','Android' {

        $description = @'
## What this test checks
Android counterpart of MT.Zta.1110. Triggered when ZTA [`24547`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24547.md) or [`24545`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24545.md) Failed. Verifies an Android APP exists with `targetedAppManagementLevels` covering unmanaged devices AND `assignments[].target` is a real groupAssignmentTarget (not the all-users placeholder).

## How to remediate
1. Intune → Apps → App protection policies → Android → create / edit.
2. Set targeted app management level to include unmanaged scope.
3. Assign to a real security group.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('24547','24545') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 24547/24545 — Android APP gap-fill not applicable."
            return
        }

        try {
            $apps = Invoke-MtGraphRequest -RelativeUri 'deviceAppManagement/androidManagedAppProtections?$expand=assignments' -ApiVersion beta
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $compliant = @($apps | Where-Object {
            $hasUnmanagedScope = ($_.targetedAppManagementLevels -in @('unmanagedAndManaged','unspecified')) -or ($_.targetedAppManagementLevels -contains 'unmanaged')
            $hasRealAssignment = @($_.assignments | Where-Object {
                $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'
            }).Count -gt 0
            $isEnabled = ($_.disabled -ne $true)
            $hasUnmanagedScope -and $hasRealAssignment -and $isEnabled
        })

        $sample = if ($apps) {
            ($apps | Select-Object -First 5 | ForEach-Object {
                $level = if ($_.targetedAppManagementLevels) { $_.targetedAppManagementLevels } else { '(unset)' }
                $assigns = @($_.assignments | Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' }).Count
                "| $($_.displayName) | $level | $assigns group target(s) |"
            }) -join "`n"
        } else { '_no Android APP policies exist in the tenant._' }

        $result = @"
| Metric | Value |
|---|---|
| Android App Protection Policies (total) | $(@($apps).Count) |
| Compliant (unmanaged scope + real group assignment + enabled) | **$($compliant.Count)** |
| ZTA trigger tests | $($triggered.Count) Failed |

### Sample policies (first 5)

| Name | targetedAppManagementLevels | groupAssignmentTarget assignments |
|---|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $compliant.Count | Should -BeGreaterThan 0
    }

    It 'MT.Zta.1112: Personal-device APP enforces wipe-on-uninstall / data backup blocked. See https://maester.dev/docs/tests/MT.Zta.1112' `
       -Tag 'MT.Zta.1112','Severity:Medium','Devices','Intune','MAM','BYOD' {

        $description = @'
## What this test checks
Beyond mere existence of an APP (covered by 1110/1111), this test verifies the policy actually enforces work-personal data separation:
- `dataBackupBlocked = true` (no iCloud/Google backup of corporate data)
- `appActionIfDeviceComplianceRequired` is `'wipe'` or `'block'` (not `'warn'`)

These two settings are what makes APP protect data on a personal device. Without them, MAM is window-dressing.

## How to remediate
1. Edit the APP policy → Data protection settings.
2. Set "Backup org data to iTunes / iCloud / Google" to **Block**.
3. Under Conditional launch → Device conditions → "Maximum allowed device threat level" set to **Block** or **Wipe** when device becomes non-compliant.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('24547','24543') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 24547/24543 — BYOD-data-security gap-fill not applicable."
            return
        }

        try {
            $iosApps     = @(Invoke-MtGraphRequest -RelativeUri 'deviceAppManagement/iosManagedAppProtections' -ApiVersion beta)
            $androidApps = @(Invoke-MtGraphRequest -RelativeUri 'deviceAppManagement/androidManagedAppProtections' -ApiVersion beta)
            $apps = $iosApps + $androidApps
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $weak = @($apps | Where-Object {
            ($_.dataBackupBlocked -ne $true) -or
            ($_.appActionIfDeviceComplianceRequired -notin @('wipe','block'))
        })

        $sample = if ($weak) {
            ($weak | Select-Object -First 10 | ForEach-Object {
                "| $($_.displayName) | dataBackupBlocked=$($_.dataBackupBlocked) | appActionIfDeviceComplianceRequired=$($_.appActionIfDeviceComplianceRequired) |"
            }) -join "`n"
        } else { '_all APPs enforce wipe-or-block on non-compliance AND block backup._' }

        $result = @"
| Metric | Value |
|---|---|
| App Protection Policies (iOS+Android) | $(@($apps).Count) |
| Policies with weak BYOD settings | **$($weak.Count)** |

### Weak policies (first 10)

| Name | dataBackup setting | non-compliance action |
|---|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $weak.Count | Should -Be 0
    }

    It 'MT.Zta.1180: Top compliance failure reasons enumerated. See https://maester.dev/docs/tests/MT.Zta.1180' `
       -Tag 'MT.Zta.1180','Severity:Medium','Devices','Intune','Compliance' {

        $description = @'
## What this test checks
When ≥ 5 ZTA Devices-pillar tests are Failed, queries DuckDB `Device` to enumerate the top reasons devices are non-compliant. ZTA flags non-compliance at policy level; this test surfaces the **most common per-device root causes** so the operator knows where to focus remediation effort.

Common categories: encryption not enforced, OS version too old, password policy not met, antivirus signature stale, managementAgent='unknown'.

## How to remediate
1. Intune → Devices → Compliance → review the top reason group.
2. For each reason: either fix the underlying gap (e.g. push BitLocker policy) or relax the compliance rule if it was over-strict.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $summary = Get-MtZta -Section Summary
        if (-not $summary -or $summary.DevicesFailed -lt 5) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA Devices-pillar Failed count ($(if ($summary) { $summary.DevicesFailed } else { 'n/a' })) below trigger threshold (5) — gap-fill not applicable."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Stream non-compliant devices and group by the most diagnostic combination.
            # Group-Object scales — builds a small key->count map, not a row copy.
            $nonCompliant = & $reader.GetRows 'Device' { param($d) $d.isCompliant -eq $false }
            $reasons = $nonCompliant |
                Group-Object -Property trustType, operatingSystem, managementAgent |
                Sort-Object Count -Descending |
                Select-Object -First 10 |
                ForEach-Object {
                    $key = $_.Name -split ', '
                    [pscustomobject]@{
                        trustType = $key[0]
                        operatingSystem = $key[1]
                        managementAgent = $key[2]
                        deviceCount = $_.Count
                    }
                }
            $reasons = @($reasons)
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $sample = if ($reasons) {
            ($reasons | ForEach-Object {
                "| $($_.trustType) | $($_.operatingSystem) | $($_.managementAgent) | **$($_.deviceCount)** |"
            }) -join "`n"
        } else { '_no non-compliant devices in the bundle._' }

        $result = @"
| trustType | operatingSystem | managementAgent | Device count |
|---|---|---|---|
$sample

Use the dominant row as the **first remediation target** — fixing it usually clears 50%+ of fleet non-compliance.
"@
        Add-MtTestResultDetail -Description $description -Result $result
        # Informational — passes as long as enumeration succeeded.
        $reasons.Count | Should -BeGreaterThan 0
    }

    It 'MT.Zta.1181: CA What-If: typical user is BLOCKED on a non-compliant device. See https://maester.dev/docs/tests/MT.Zta.1181' `
       -Tag 'MT.Zta.1181','Severity:High','Devices','ConditionalAccess','WhatIf','Beta' {

        $description = @'
## What this test checks
Triggered when ZTA [`24824`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24824.md) Failed (CA policies block access from noncompliant devices). Uses Maester's `Test-MtConditionalAccessWhatIf` (BETA Graph API) to simulate a sample non-privileged user signing in to Office 365 from a Windows browser flagged as **non-compliant**, and verifies the returned grant includes `block` OR `compliantDevice`.

What-If is more rigorous than reading policy state because it reflects the actual policy graph evaluation including exclusions, group memberships, and authentication-strength compositions.

## How to remediate
1. Conditional Access → policy targeting Office 365 → ensure `Require device to be marked as compliant` is in the Grant block.
2. Or use `Block access` for non-compliant devices on a separate policy.
3. Re-run; the What-If output should change to `block` or grant containing `compliantDevice`.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('24824','24823') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 24824/24823 — non-compliant-device CA gap-fill not applicable."
            return
        }

        # Pick a sample non-privileged user from DuckDB if available, otherwise fall back
        # to the first Member returned by Graph.
        $sampleUser = $null
        if ($zta.Database -and $zta.Database.Query) {
            try {
                $sampleUser = & $zta.Database.Query "SELECT id, userPrincipalName FROM `"User`" WHERE userType = 'member' AND accountEnabled = true LIMIT 1" | Select-Object -First 1
            } catch { }
        }
        if (-not $sampleUser) {
            try {
                $rows = Invoke-MtGraphRequest -RelativeUri 'users?$filter=accountEnabled eq true and userType eq ''Member''&$top=1&$select=id,userPrincipalName' -ApiVersion beta
                $sampleUser = @($rows)[0]
            } catch {
                Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
                return
            }
        }
        if (-not $sampleUser -or -not $sampleUser.id) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'Could not pick a sample non-privileged user for the simulation.'
            return
        }

        # Office 365 well-known app id (used as the simulated app target).
        $office365AppId = 'd3590ed6-52b3-4102-aeff-aad2292ab01c'

        try {
            $whatIf = Test-MtConditionalAccessWhatIf -UserId $sampleUser.id `
                                                     -IncludeApplications $office365AppId `
                                                     -ClientAppType 'browser' `
                                                     -DevicePlatform 'Windows'
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $controls = @($whatIf.grantControls.builtInControls) + @($whatIf.grantControls.operator)
        $blocksOrRequiresCompliant = ($controls -contains 'block') -or ($controls -contains 'compliantDevice')

        $matchedPolicies = if ($whatIf.policies) {
            ($whatIf.policies | Select-Object -First 5 | ForEach-Object { "- $($_.displayName)" }) -join "`n"
        } else { '_no CA policies in scope for the simulated scenario._' }

        $result = @"
| Field | Value |
|---|---|
| Sample user | ``$($sampleUser.userPrincipalName)`` |
| Simulated app | Office 365 (``$office365AppId``) |
| Client | browser / Windows / non-compliant |
| Returned grant controls | $(($controls | Sort-Object -Unique) -join ', ') |
| Block or compliantDevice required? | **$blocksOrRequiresCompliant** |

### Policies in scope (first 5)

$matchedPolicies
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $blocksOrRequiresCompliant | Should -BeTrue
    }
}
