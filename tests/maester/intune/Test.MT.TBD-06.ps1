function Test-MtAndroidPasswordPolicy {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android compliance policy requires a strong device password.

    .DESCRIPTION
    The device password is what stands between someone holding the phone and everything on it: corporate
    mail, Teams conversations, and the Microsoft Authenticator app, which is the second factor for the
    signed-in user. A phone with no password hands all of that to whoever picks it up.

    Three settings make up the control and this check requires all three on the same policy:

    - A password is required at all (passwordRequired).
    - The password is at least MinimumPasswordLength characters (passwordMinimumLength).
    - The screen locks after at most MaximumInactivityMinutes of inactivity
      (passwordMinutesOfInactivityBeforeLock), because a password on a screen that never locks
      protects nothing.

    They are checked together rather than as three tests because they are one control, and they must
    hold on the same policy, since a device is evaluated against each policy as a whole.

    An inactivity timeout that is not configured does not count as a pass. Treating a missing value as
    "no limit, so under the limit" would report the weakest possible configuration as compliant.

    The required password complexity (requiredPasswordComplexity) is reported for every policy but does
    not decide the verdict, because the set of values that property accepts is not verified here. An
    unrecognised value is shown as returned rather than being labelled.

    Only #microsoft.graph.androidCompliancePolicy, the device administrator policy type, is evaluated.
    Android Enterprise policies are reported but not evaluated, and a tenant that has only those is
    reported as not applicable rather than as a failure. See the scope limitation in the guide.

    .PARAMETER MinimumPasswordLength
    Shortest password length, in characters, that the policy may require.

    .PARAMETER MaximumInactivityMinutes
    Longest inactivity period, in minutes, that the policy may allow before the screen locks.

    .EXAMPLE
    Test-MtAndroidPasswordPolicy

    Returns true if at least one assigned Android compliance policy requires a strong device password.

    .EXAMPLE
    Test-MtAndroidPasswordPolicy -MinimumPasswordLength 8 -MaximumInactivityMinutes 5

    Returns true if at least one assigned Android compliance policy requires at least eight characters
    and locks the screen after five minutes.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidPasswordPolicy
    #>
    [MaesterTest(
        Id = 'MT.TBD-06',
        Title = 'Ensure Android compliance policy requires a strong device password.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'High',
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
        # Shortest password length, in characters, that the policy may require.
        [ValidateRange(4, 16)]
        [int] $MinimumPasswordLength = 6,

        # Longest inactivity period, in minutes, that the policy may allow before the screen locks.
        [ValidateRange(1, 240)]
        [int] $MaximumInactivityMinutes = 15
    )

    try {
        Write-Verbose "Querying Android compliance policies..."
        $policies = Get-MtMobileCompliancePolicy -Platform Android
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No Android compliance policies were found in Intune.`n`n"
            $testResultMarkdown += "Without an Android compliance policy, a phone with no password is still reported as compliant. "
            $testResultMarkdown += "Create an Android compliance policy and require a password of at least "
            $testResultMarkdown += "$MinimumPasswordLength characters that locks the screen after $MaximumInactivityMinutes minutes."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $evaluated = @($policies | Where-Object { $_.SettingsEvaluated })
        $enterprise = @($policies | Where-Object { -not $_.SettingsEvaluated })
        if ($evaluated.Count -eq 0) {
            # The tenant manages Android through Android Enterprise only. These settings are read from
            # the device administrator policy type, so there is nothing to evaluate here.
            Add-MtTestResultDetail -SkippedBecause NotApplicable
            return $null
        }

        # A missing inactivity value must not pass: $null -le a number is true in PowerShell, so the
        # value is required to be a real, positive number before it is compared.
        $compliant = @($evaluated | Where-Object {
                $_.IsAssigned -and
                $_.PasswordRequired -and
                $_.PasswordMinimumLength -ge $MinimumPasswordLength -and
                $_.PasswordInactivityMinutes -gt 0 -and
                $_.PasswordInactivityMinutes -le $MaximumInactivityMinutes
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($evaluated.Count) Android device administrator compliance policy/policies in Intune. "
        $testResultMarkdown += "Required: a password of at least $MinimumPasswordLength characters "
        $testResultMarkdown += "and the screen locked after at most $MaximumInactivityMinutes minutes.`n`n"
        $testResultMarkdown += "| Policy | Password required | Minimum length | Locks after | Complexity | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($policy in $evaluated) {
            $requiredState = if ($policy.PasswordRequired) { 'Yes' } else { 'No' }
            $lengthState = if ($policy.PasswordMinimumLength -gt 0) { $policy.PasswordMinimumLength } else { 'Not configured' }
            $lockState = if ($policy.PasswordInactivityMinutes -gt 0) { "$($policy.PasswordInactivityMinutes) min" } else { 'Not configured' }
            # Reported as returned: the values this property accepts are not verified here, so an
            # unrecognised one must not be relabelled.
            $complexityState = if ([string]::IsNullOrWhiteSpace($policy.PasswordComplexity)) { 'Not reported' } else { $policy.PasswordComplexity }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $requiredState | $lengthState | $lockState | $complexityState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android compliance policy requires a strong device password."
            $gaps = @($evaluated | Where-Object { $_.IsAssigned -and $_.Id -notin $compliant.Id })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet every password requirement. "
                $testResultMarkdown += "Devices scoped only to those policies are held to a weaker password."
            }
        } else {
            $unassigned = @($evaluated | Where-Object {
                    -not $_.IsAssigned -and $_.PasswordRequired -and
                    $_.PasswordMinimumLength -ge $MinimumPasswordLength -and
                    $_.PasswordInactivityMinutes -gt 0 -and $_.PasswordInactivityMinutes -le $MaximumInactivityMinutes
                })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies require a strong password but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your Android device or user groups."
            } else {
                $testResultMarkdown += "`nNo assigned Android compliance policy requires a strong device password. "
                $testResultMarkdown += "Whoever holds the device reaches corporate mail and the Microsoft Authenticator app on it."
            }
        }

        if ($enterprise.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Scope:** $($enterprise.Count) Android Enterprise compliance policy/policies "
            $testResultMarkdown += "(work profile or device owner) are configured in this tenant and are **not evaluated** by this test."
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
