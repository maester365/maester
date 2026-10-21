function Test-MtAndroidDeviceAdministratorBlocked {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android compliance policy blocks devices managed with device administrator.

    .DESCRIPTION
    Android device administrator is the legacy management mode. Google deprecated the APIs it is built
    on, newer Android releases ignore a growing share of them, and the hardening that Android Enterprise
    brings, a separate work profile, Play Integrity attestation and per-profile policy, does not exist
    there. A device administrator enrollment is therefore managed in name while the controls an admin
    believes are applied quietly stop being enforced.

    The Android compliance policy can mark such enrollments non-compliant through
    securityBlockDeviceAdministratorManagedDevices, which is how an organization drives the migration
    to Android Enterprise instead of discovering, years later, that part of the fleet was never
    protected.

    This is a modernization control, not a defence against a technique, so it declares no ATT&CK
    mapping. Its cost falls on users: a device that is blocked has to be re-enrolled, and it loses
    access until it is.

    This test passes if at least one Android compliance policy that is assigned to a group blocks
    device administrator managed devices. Policies with no assignment are reported but do not count
    towards a pass, because an unassigned compliance policy is never evaluated.

    A tenant with no device administrator compliance policy at all is reported as not applicable: there
    is nothing to configure, and MT.1054 covers whether devices with no policy assigned are treated as
    non-compliant.

    .EXAMPLE
    Test-MtAndroidDeviceAdministratorBlocked

    Returns true if at least one assigned Android compliance policy blocks devices managed with device administrator.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidDeviceAdministratorBlocked
    #>
    [MaesterTest(
        Id = 'MT.TBD-10',
        Title = 'Ensure Android compliance policy blocks devices managed with device administrator.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Control = ('nist-800-53-r5:AC-19', 'nist-800-53-r5:CM-6'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose "Querying Android compliance policies..."
        $policies = Get-MtMobileCompliancePolicy -Platform Android
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        $evaluated = @($policies | Where-Object { $_.SettingsEvaluated })
        $enterprise = @($policies | Where-Object { -not $_.SettingsEvaluated })
        if ($evaluated.Count -eq 0) {
            # No device administrator compliance policy exists, so the setting has nowhere to live and
            # its absence is not a finding. MT.1054 covers devices with no policy assigned.
            Add-MtTestResultDetail -SkippedBecause NotApplicable
            return $null
        }

        $compliant = @($evaluated | Where-Object { $_.BlocksDeviceAdministrator -and $_.IsAssigned })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($evaluated.Count) Android device administrator compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Device administrator managed devices | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $evaluated) {
            $daState = if ($policy.BlocksDeviceAdministrator) { 'Blocked' } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $daState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android compliance policy blocks devices managed with device administrator."
            $gaps = @($evaluated | Where-Object { -not $_.BlocksDeviceAdministrator -and $_.IsAssigned })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies still accept device administrator enrollments. "
                $testResultMarkdown += "Devices scoped only to those policies keep access in the legacy management mode."
            }
        } else {
            $unassigned = @($evaluated | Where-Object { $_.BlocksDeviceAdministrator -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies block device administrator managed devices but are **not assigned** to "
                $testResultMarkdown += "any group, so they are never evaluated. Assign the policy to your Android device or user groups."
            } else {
                $testResultMarkdown += "`nNo Android compliance policy blocks devices managed with device administrator. "
                $testResultMarkdown += "Those enrollments stay compliant while the policies an admin believes are applied are no longer enforced by Android."
            }
        }

        if ($enterprise.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Scope:** $($enterprise.Count) Android Enterprise compliance policy/policies "
            $testResultMarkdown += "(work profile or device owner) are configured in this tenant. They are the target of the migration this check drives."
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
