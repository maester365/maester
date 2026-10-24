function Test-MtIosMinimumOsVersion {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS compliance policy requires a minimum operating system version.

    .DESCRIPTION
    Apple ships security fixes only in the current iOS release. A device left on an older major version
    keeps every browser engine and kernel vulnerability that release carried, including the ones Apple
    has published as actively exploited, and nothing in Intune makes the user install the update.

    A minimum OS version in a compliance policy is how the tenant notices. A device below the version
    is marked non-compliant and can then be blocked by Conditional Access, which turns "please update"
    into a condition for access.

    By default this check only requires that a minimum version is set at all, because the version that
    is current ages out of any value fixed in a test. Set MinimumOsVersion to hold the tenant to a
    specific version, for example '18.0'.

    A version that cannot be compared with the required one is reported with its raw value and does not
    count towards a pass, rather than being guessed at in either direction. Intune accepts a single part
    value such as '18', which is read here as '18.0' because [version] needs two parts.

    This test passes if at least one iOS compliance policy that is assigned to a group sets a minimum
    version. Policies with no assignment are reported but do not count towards a pass, because an
    unassigned compliance policy is never evaluated.

    .PARAMETER MinimumOsVersion
    Lowest iOS version the policy may accept, for example '18.0'. Empty requires only that a version is set.

    .EXAMPLE
    Test-MtIosMinimumOsVersion

    Returns true if at least one assigned iOS compliance policy sets a minimum operating system version.

    .EXAMPLE
    Test-MtIosMinimumOsVersion -MinimumOsVersion '18.0'

    Returns true if at least one assigned iOS compliance policy requires iOS 18.0 or later.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosMinimumOsVersion
    #>
    [MaesterTest(
        Id = 'MT.1230',
        Title = 'Ensure iOS compliance policy requires a minimum operating system version.',
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
        # Lowest iOS version the policy may accept, for example '18.0'. Empty requires only that a version is set.
        [ValidatePattern('^$|^\d+(\.\d+){0,3}$')]
        [string] $MinimumOsVersion = ''
    )

    Write-Verbose "Querying iOS compliance policies..."
    try {
        $policies = Get-MtMobileCompliancePolicy -Platform iOS
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
        $testResultMarkdown = "No iOS compliance policies were found in Intune.`n`n"
        $testResultMarkdown += "Without an iOS compliance policy, an iPhone several major versions behind is still reported as compliant. "
        $testResultMarkdown += "Create an iOS/iPadOS compliance policy and set **Minimum OS version**."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }

    # Intune accepts '18' as well as '18.0', and [version] rejects a single part value. Padding is
    # applied to a value that is only digits; anything else is left alone so that it fails to parse
    # and is reported as not comparable instead of being guessed at.
    $hasRequired = -not [string]::IsNullOrWhiteSpace($MinimumOsVersion)
    $required = if ($hasRequired) { [version]($MinimumOsVersion.Trim() -replace '^(\d+)$', '${1}.0') } else { $null }

    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($policy in $policies) {
        $raw = "$($policy.MinimumOsVersion)".Trim()
        $isSet = -not [string]::IsNullOrWhiteSpace($raw)
        $comparable = $true
        $meets = $false
        if ($isSet -and -not $hasRequired) {
            # No required version configured: any version that is set counts.
            $meets = $true
        } elseif ($isSet) {
            $parsed = $null
            $comparable = [version]::TryParse(($raw -replace '^(\d+)$', '${1}.0'), [ref] $parsed)
            $meets = ($comparable -and $parsed -ge $required)
        }
        $rows.Add([pscustomobject]@{
                Name       = $policy.Name
                Version    = if ($isSet) { $raw } else { 'Not configured' }
                Comparable = $comparable
                Meets      = $meets
                IsAssigned = $policy.IsAssigned
                Assignment = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            })
    }

    $compliant = @($rows | Where-Object { $_.IsAssigned -and $_.Meets })
    $testResult = $compliant.Count -gt 0

    $requirement = if ($hasRequired) { "iOS $MinimumOsVersion or later" } else { 'any minimum version' }
    $testResultMarkdown = "Found $($policies.Count) iOS compliance policy/policies in Intune. Required: $requirement.`n`n"
    $testResultMarkdown += "| Policy | Minimum OS version | Assignments |`n"
    $testResultMarkdown += "| --- | --- | --- |`n"
    foreach ($row in $rows) {
        $versionState = if (-not $row.Comparable) { "$($row.Version) (cannot be compared)" } else { $row.Version }
        $testResultMarkdown += "| $($row.Name) | $versionState | $($row.Assignment) |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. At least one assigned iOS compliance policy sets a minimum operating system version."
        $gaps = @($rows | Where-Object { $_.IsAssigned -and -not $_.Meets })
        if ($gaps.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not require $requirement. "
            $testResultMarkdown += "Devices scoped only to those policies may run an unpatched iOS release."
        }
    } else {
        $unassigned = @($rows | Where-Object { -not $_.IsAssigned -and $_.Meets })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies set a minimum operating system version but are **not assigned** to any group, "
            $testResultMarkdown += "so they are never evaluated. Assign the policy to your iOS device or user groups."
        } else {
            $testResultMarkdown += "`nNo assigned iOS compliance policy requires $requirement. "
            $testResultMarkdown += "A device left on an older major version keeps the vulnerabilities that release carried and stays compliant."
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
