# ZTA pillar-level fail-count gates for the three non-Identity pillars.
# Mirrors MT.Zta.1001 (Identity) for Devices/Network/Data so each pillar gets a
# single bulk-failure signal independent of bucket-level analysis.

Describe 'ZTA per-pillar fail count' -Tag 'ZTA' {

    It 'MT.Zta.1004: Devices pillar fail count is below the warn threshold. See https://maester.dev/docs/tests/MT.Zta.1004' -Tag 'MT.Zta.1004','Severity:High','Devices','Intune','Compliance' {
        $zta     = Get-MtZta
        $summary = if ($zta) { Get-MtZta -Section Summary } else { $null }

        $description = @'
## What this test checks
ZTA's **Devices pillar** covers Intune compliance, BitLocker / FileVault enforcement, OS-version posture, and conditional-access compliant-device requirements. A bulk failure (≥ 20 Devices tests Failed) usually indicates a missing compliance policy assignment or a stale grace period rather than per-device drift.

## How to remediate
1. Intune → Devices → Compliance policies — verify a baseline policy is assigned to all platforms in scope.
2. Intune → Endpoint security → Disk encryption — confirm enforcement on Windows + macOS.
3. Conditional Access — verify "require compliant device" is enforced on the platform pillars.
'@

        if (-not $summary) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1004' -Default 20
        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Devices Failed | **$($summary.DevicesFailed)** | $threshold |
| Devices Passed | $($summary.DevicesPassed) | — |
| Devices Skipped | $($summary.DevicesSkipped) | — |
| Fail ratio | $($summary.DevicesFailRatio) | — |
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $summary.DevicesFailed | Should -BeLessThan $threshold
    }

    It 'MT.Zta.1005: Network pillar fail count is below the warn threshold. See https://maester.dev/docs/tests/MT.Zta.1005' -Tag 'MT.Zta.1005','Severity:Medium','Network','GSA','GlobalSecureAccess' {
        $zta     = Get-MtZta
        $summary = if ($zta) { Get-MtZta -Section Summary } else { $null }

        $description = @'
## What this test checks
ZTA's **Network pillar** covers Global Secure Access (GSA), private-network access, internet access policy, and network-aware conditional access. Bulk failures here usually mean GSA is not deployed, or GSA tunnels are mis-scoped.

## How to remediate
1. Entra ID → Global Secure Access — verify the tenant is enrolled and at least one of {Microsoft Traffic, Internet Access, Private Access} is provisioned.
2. CA — verify a network-aware policy enforces GSA for in-scope users.
'@

        if (-not $summary) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1005' -Default 15
        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Network Failed | **$($summary.NetworkFailed)** | $threshold |
| Network Passed | $($summary.NetworkPassed) | — |
| Network Skipped | $($summary.NetworkSkipped) | — |
| Fail ratio | $($summary.NetworkFailRatio) | — |
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $summary.NetworkFailed | Should -BeLessThan $threshold
    }

    It 'MT.Zta.1006: Data pillar fail count is below the warn threshold. See https://maester.dev/docs/tests/MT.Zta.1006' -Tag 'MT.Zta.1006','Severity:Medium','Data','Purview','Sensitivity' {
        $zta     = Get-MtZta
        $summary = if ($zta) { Get-MtZta -Section Summary } else { $null }

        $description = @'
## What this test checks
ZTA's **Data pillar** covers sensitivity-label coverage, DLP policy reach, and Purview-driven data classification. Bulk failures usually mean Purview isn't licensed/configured, OR labels exist but aren't published to the right scope.

## How to remediate
1. Purview portal → Information protection → Labels — verify at least one published label policy.
2. Purview → Data loss prevention → Policies — verify default DLP policies for Exchange + SharePoint + Teams.
3. Sensitivity label auto-labelling — verify it's enabled for E5/AIP-licensed users.
'@

        if (-not $summary) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1006' -Default 15
        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Data Failed | **$($summary.DataFailed)** | $threshold |
| Data Passed | $($summary.DataPassed) | — |
| Data Skipped | $($summary.DataSkipped) | — |
| Fail ratio | $($summary.DataFailRatio) | — |
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $summary.DataFailed | Should -BeLessThan $threshold
    }
}
