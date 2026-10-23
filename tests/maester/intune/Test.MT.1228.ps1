function Test-MtIosJailbrokenDevices {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS compliance policy blocks jailbroken devices.

    .DESCRIPTION
    A jailbroken iPhone or iPad has had the chain of platform protections that iOS is trusted for
    removed: code signing enforcement, the app sandbox and the protections around the keychain. Apps
    from outside the App Store run unsigned, one app can read another app's data, and credentials and
    tokens that iOS stores for the Microsoft Authenticator, Outlook and Teams become reachable.

    Intune cannot prevent a device from being jailbroken. What it can do is evaluate the jailbreak
    signal as a compliance condition, so the device is marked non-compliant and can then be blocked by
    Conditional Access. Without that rule, Intune reports a jailbroken device as healthy and it keeps
    its access to corporate resources with its platform guarantees gone.

    This test passes if at least one iOS compliance policy that is assigned to a group sets
    "Jailbroken devices" to Block. Policies with no assignment are reported but do not count towards a
    pass, because an unassigned compliance policy is never evaluated.

    .EXAMPLE
    Test-MtIosJailbrokenDevices

    Returns true if at least one assigned iOS compliance policy blocks jailbroken devices.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosJailbrokenDevices
    #>
    [MaesterTest(
        Id = 'MT.1228',
        Title = 'Ensure iOS compliance policy blocks jailbroken devices.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1068', 'T1553.006'),
        Control = ('nist-800-53-r5:SI-7', 'nist-800-53-r5:AC-19'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose "Querying iOS compliance policies..."
        $policies = Get-MtMobileCompliancePolicy -Platform iOS
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No iOS compliance policies were found in Intune.`n`n"
            $testResultMarkdown += "Without an iOS compliance policy, a jailbroken iPhone or iPad is still reported as compliant. "
            $testResultMarkdown += "Create an iOS/iPadOS compliance policy and set **Jailbroken devices** to **Block**."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $compliant = @($policies | Where-Object { $_.BlocksJailbrokenDevices -and $_.IsAssigned })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) iOS compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Jailbroken devices | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $jailbreakState = if ($policy.BlocksJailbrokenDevices) { 'Blocked' } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $jailbreakState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned iOS compliance policy blocks jailbroken devices."
            $gaps = @($policies | Where-Object { -not $_.BlocksJailbrokenDevices -and $_.IsAssigned })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not block jailbroken devices. "
                $testResultMarkdown += "Devices scoped only to those policies are not evaluated for jailbreak detection."
            }
        } else {
            $unassigned = @($policies | Where-Object { $_.BlocksJailbrokenDevices -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies block jailbroken devices but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your iOS device or user groups."
            } else {
                $testResultMarkdown += "`nNo iOS compliance policy blocks jailbroken devices. "
                $testResultMarkdown += "A jailbroken device is reported as compliant and keeps access to corporate resources."
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
