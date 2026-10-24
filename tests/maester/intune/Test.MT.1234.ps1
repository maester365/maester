function Test-MtAndroidSecurityPatchLevel {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android compliance policy requires a recent security patch level.

    .DESCRIPTION
    Android publishes a security patch level, a date, that says which monthly bulletin a device has
    received. It is the only practical way to tell whether a phone carries the fixes for the kernel and
    media vulnerabilities Google has published, because the version number alone does not say: two
    phones on the same Android release can be a year apart in patches, which is routine on devices
    whose manufacturer has stopped shipping updates.

    A minimum security patch level in a compliance policy is how the tenant notices. A device below the
    date is marked non-compliant and can then be blocked by Conditional Access.

    A date that is itself old makes the setting pointless: a policy that requires patches from three
    years ago accepts every device. This check therefore requires both that the setting is configured
    and that the date is no older than MaximumPatchLevelAgeInDays, a year by default.

    A value that cannot be read as a date is reported with its raw value and does not count towards a
    pass, rather than being guessed at in either direction.

    Only #microsoft.graph.androidCompliancePolicy, the device administrator policy type, is evaluated.
    Android Enterprise policies are reported but not evaluated, and a tenant that has only those is
    reported as not applicable rather than as a failure. See the scope limitation in the guide.

    .PARAMETER MaximumPatchLevelAgeInDays
    Oldest security patch level, in days before today, that a policy may still require.

    .EXAMPLE
    Test-MtAndroidSecurityPatchLevel

    Returns true if at least one assigned Android compliance policy requires a security patch level from the last year.

    .EXAMPLE
    Test-MtAndroidSecurityPatchLevel -MaximumPatchLevelAgeInDays 180

    Returns true if at least one assigned Android compliance policy requires a security patch level from the last six months.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidSecurityPatchLevel
    #>
    [MaesterTest(
        Id = 'MT.1234',
        Title = 'Ensure Android compliance policy requires a recent security patch level.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1203', 'T1068'),
        Control = ('nist-800-53-r5:SI-2', 'nist-800-53-r5:CM-6'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Oldest security patch level, in days before today, that a policy may still require.
        [ValidateRange(30, 3650)]
        [int] $MaximumPatchLevelAgeInDays = 365
    )

    Write-Verbose "Querying Android compliance policies..."
    try {
        $policies = Get-MtMobileCompliancePolicy -Platform Android
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        throw
    }

    if ($null -eq $policies) {
        # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
        # Report a skip rather than a false security finding.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    if ($policies.Count -eq 0) {
        $testResultMarkdown = "No Android compliance policies were found in Intune.`n`n"
        $testResultMarkdown += "Without an Android compliance policy, a phone that stopped receiving security patches years ago is still "
        $testResultMarkdown += "reported as compliant. Create an Android compliance policy and set **Minimum security patch level**."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }

    $evaluated = @($policies | Where-Object { $_.SettingsEvaluated })
    $enterprise = @($policies | Where-Object { -not $_.SettingsEvaluated })
    if ($evaluated.Count -eq 0) {
        # The tenant manages Android through Android Enterprise only. This setting is read from the
        # device administrator policy type, so there is nothing to evaluate here.
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $today = [datetime]::UtcNow.Date
    $oldestAccepted = $today.AddDays(-$MaximumPatchLevelAgeInDays)

    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($policy in $evaluated) {
        $raw = "$($policy.MinimumSecurityPatchLevel)".Trim()
        $isSet = -not [string]::IsNullOrWhiteSpace($raw)
        $parsed = [datetime]::MinValue
        # Graph returns the patch level as yyyy-MM-dd. Parsed with the invariant culture so the
        # result does not depend on the locale of the machine running Maester.
        $comparable = $isSet -and [datetime]::TryParseExact(
            $raw, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None, [ref] $parsed)
        $meets = ($comparable -and $parsed -ge $oldestAccepted)
        $rows.Add([pscustomobject]@{
                Name       = $policy.Name
                PatchLevel = if ($isSet) { $raw } else { 'Not configured' }
                Comparable = $comparable
                Meets      = $meets
                IsAssigned = $policy.IsAssigned
                Assignment = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            })
    }

    $compliant = @($rows | Where-Object { $_.IsAssigned -and $_.Meets })
    $testResult = $compliant.Count -gt 0

    $testResultMarkdown = "Found $($evaluated.Count) Android device administrator compliance policy/policies in Intune. "
    $testResultMarkdown += "Required: a security patch level on or after $($oldestAccepted.ToString('yyyy-MM-dd')) "
    $testResultMarkdown += "($MaximumPatchLevelAgeInDays days).`n`n"
    $testResultMarkdown += "| Policy | Minimum security patch level | Assignments |`n"
    $testResultMarkdown += "| --- | --- | --- |`n"
    foreach ($row in $rows) {
        $patchState = if ($row.PatchLevel -ne 'Not configured' -and -not $row.Comparable) {
            "$($row.PatchLevel) (not a date)"
        } elseif ($row.Comparable -and -not $row.Meets) {
            "$($row.PatchLevel) (too old)"
        } else {
            $row.PatchLevel
        }
        $testResultMarkdown += "| $($row.Name) | $patchState | $($row.Assignment) |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. At least one assigned Android compliance policy requires a recent security patch level."
        $gaps = @($rows | Where-Object { $_.IsAssigned -and -not $_.Meets })
        if ($gaps.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not require a patch level from the last "
            $testResultMarkdown += "$MaximumPatchLevelAgeInDays days. Devices scoped only to those policies may be years behind on patches."
        }
    } else {
        $unassigned = @($rows | Where-Object { -not $_.IsAssigned -and $_.Meets })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies require a recent security patch level but are **not assigned** to any "
            $testResultMarkdown += "group, so they are never evaluated. Assign the policy to your Android device or user groups."
        } else {
            # A value that is set but unreadable still counts as "a date is configured": saying no
            # policy requires one would contradict the table above it.
            $withValue = @($rows | Where-Object { $_.IsAssigned -and $_.PatchLevel -ne 'Not configured' })
            if ($withValue.Count -gt 0) {
                $testResultMarkdown += "`nThe security patch level required by the assigned policies is older than $MaximumPatchLevelAgeInDays days, "
                $testResultMarkdown += "or could not be read as a date, so it does not hold devices to a recent security bulletin. Move the date forward."
            } else {
                $testResultMarkdown += "`nNo assigned Android compliance policy requires a minimum security patch level. "
                $testResultMarkdown += "A phone whose manufacturer stopped shipping updates stays compliant and keeps access to corporate resources."
            }
        }
    }

    if ($enterprise.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Scope:** $($enterprise.Count) Android Enterprise compliance policy/policies "
        $testResultMarkdown += "(work profile or device owner) are configured in this tenant and are **not evaluated** by this test."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
