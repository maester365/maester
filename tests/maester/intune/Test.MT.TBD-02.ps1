function Test-MtIosPasscodePolicy {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS compliance policy requires a strong device passcode.

    .DESCRIPTION
    The passcode is what stands between someone holding the device and everything on it. On a managed
    iPhone that is corporate mail, Teams conversations, and the Microsoft Authenticator app, which is
    the second factor for the signed-in user. A phone with no passcode, or with a four digit simple
    passcode, hands all of that to whoever picks it up.

    Four settings make up the control and this check requires all four on the same policy:

    - A passcode is required at all (passcodeRequired).
    - Simple passcodes such as 1234 or repeated digits are blocked (passcodeBlockSimple).
    - The passcode is at least MinimumPasscodeLength characters (passcodeMinimumLength).
    - The screen locks after at most MaximumInactivityMinutes of inactivity
      (passcodeMinutesOfInactivityBeforeLock), because a passcode on a screen that never locks
      protects nothing.

    They are checked together rather than as four tests because they are one control: a required
    passcode with no length or lock timeout is not a passcode policy. They must also hold on the same
    policy, since a device is evaluated against each policy as a whole.

    An inactivity timeout that is not configured does not count as a pass. Treating a missing value as
    "no limit, so under the limit" would report the weakest possible configuration as compliant.

    This test passes if at least one iOS compliance policy that is assigned to a group satisfies all
    four. Policies with no assignment are reported but do not count towards a pass, because an
    unassigned compliance policy is never evaluated.

    .PARAMETER MinimumPasscodeLength
    Shortest passcode length, in characters, that the policy may require.

    .PARAMETER MaximumInactivityMinutes
    Longest inactivity period, in minutes, that the policy may allow before the screen locks.

    .EXAMPLE
    Test-MtIosPasscodePolicy

    Returns true if at least one assigned iOS compliance policy requires a strong device passcode.

    .EXAMPLE
    Test-MtIosPasscodePolicy -MinimumPasscodeLength 8 -MaximumInactivityMinutes 5

    Returns true if at least one assigned iOS compliance policy requires at least eight characters and
    locks the screen after five minutes.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosPasscodePolicy
    #>
    [MaesterTest(
        Id = 'MT.TBD-02',
        Title = 'Ensure iOS compliance policy requires a strong device passcode.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1110', 'T1111'),
        Control = ('nist-800-53-r5:IA-5(1)', 'nist-800-53-r5:AC-11'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Shortest passcode length, in characters, that the policy may require.
        [ValidateRange(4, 16)]
        [int] $MinimumPasscodeLength = 6,

        # Longest inactivity period, in minutes, that the policy may allow before the screen locks.
        [ValidateRange(1, 240)]
        [int] $MaximumInactivityMinutes = 15
    )

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
            $testResultMarkdown += "Without an iOS compliance policy, an iPhone with no passcode is still reported as compliant. "
            $testResultMarkdown += "Create an iOS/iPadOS compliance policy and require a password of at least "
            $testResultMarkdown += "$MinimumPasscodeLength characters that locks the screen after $MaximumInactivityMinutes minutes."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # A missing inactivity value must not pass: $null -le a number is true in PowerShell, so the
        # value is required to be a real, positive number before it is compared.
        $compliant = @($policies | Where-Object {
                $_.IsAssigned -and
                $_.PasscodeRequired -and
                $_.PasscodeBlocksSimple -and
                $_.PasscodeMinimumLength -ge $MinimumPasscodeLength -and
                $_.PasscodeInactivityMinutes -gt 0 -and
                $_.PasscodeInactivityMinutes -le $MaximumInactivityMinutes
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) iOS compliance policy/policies in Intune. "
        $testResultMarkdown += "Required: a passcode of at least $MinimumPasscodeLength characters, simple passcodes blocked, "
        $testResultMarkdown += "and the screen locked after at most $MaximumInactivityMinutes minutes.`n`n"
        $testResultMarkdown += "| Policy | Passcode required | Simple passcodes | Minimum length | Locks after | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $requiredState = if ($policy.PasscodeRequired) { 'Yes' } else { 'No' }
            $simpleState = if ($policy.PasscodeBlocksSimple) { 'Blocked' } else { 'Allowed' }
            $lengthState = if ($policy.PasscodeMinimumLength -gt 0) { $policy.PasscodeMinimumLength } else { 'Not configured' }
            $lockState = if ($policy.PasscodeInactivityMinutes -gt 0) { "$($policy.PasscodeInactivityMinutes) min" } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $requiredState | $simpleState | $lengthState | $lockState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned iOS compliance policy requires a strong device passcode."
            $gaps = @($policies | Where-Object { $_.IsAssigned -and $_.Id -notin $compliant.Id })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet every passcode requirement. "
                $testResultMarkdown += "Devices scoped only to those policies are held to a weaker passcode."
            }
        } else {
            $unassigned = @($policies | Where-Object {
                    -not $_.IsAssigned -and $_.PasscodeRequired -and $_.PasscodeBlocksSimple -and
                    $_.PasscodeMinimumLength -ge $MinimumPasscodeLength -and
                    $_.PasscodeInactivityMinutes -gt 0 -and $_.PasscodeInactivityMinutes -le $MaximumInactivityMinutes
                })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies require a strong passcode but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your iOS device or user groups."
            } else {
                $testResultMarkdown += "`nNo assigned iOS compliance policy requires a strong device passcode. "
                $testResultMarkdown += "Whoever holds the device reaches corporate mail and the Microsoft Authenticator app on it."
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
