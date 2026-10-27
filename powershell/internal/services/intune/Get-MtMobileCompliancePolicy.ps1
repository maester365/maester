function Get-MtMobileCompliancePolicy {
    <#
    .SYNOPSIS
    Retrieves iOS or Android device compliance policies with their assignment state.

    .DESCRIPTION
    Queries Intune device compliance policies, filters to the requested mobile platform, and returns
    a normalized object per policy carrying the display name, the assignment count and the settings
    evaluated by the iOS and Android compliance checks.

    One function with a -Platform parameter rather than one function per platform: both platforms read
    the same endpoint with the same query, and the only part that is easy to get wrong is the
    read-failure contract below. Splitting it in two files would duplicate that contract twice and let
    the copies drift, while the platform-specific part is a property projection. The returned shape
    therefore depends on -Platform, and each call returns a homogeneous set.

    Assignment state is included because a compliance policy that is not assigned to any group is never
    evaluated against a device, so it cannot satisfy a security control. Only inclusion assignments
    are counted: Graph returns inclusion and exclusion targets in the same collection, so counting it
    raw would read a policy targeted only as an exclusion as assigned, when it is evaluated against
    no device. Unlike app protection, deviceCompliancePolicy exposes no server-computed isAssigned
    property, so the filtered count is the only signal there is.

    Returns $null when the compliance policies could not be read at all, so that callers can report a
    skip rather than a failure. The populated result is emitted with -NoEnumerate because PowerShell
    unrolls collections on output: an empty list would otherwise arrive at the caller as $null and be
    indistinguishable from a read failure. This matters because Invoke-MtGraphRequest surfaces a failed
    call as a non-terminating error with a null result, which collects as a single empty element.
    Treating that as "no policies exist" would produce a false negative: a security finding reported
    purely because the signed-in account lacked permission.

    Every row carries SettingsEvaluated. For Android it is $false on the Android Enterprise policy types
    (work profile and device owner), which are returned so that a caller can tell "this tenant has no
    Android compliance policy at all" from "this tenant manages Android through Android Enterprise".
    Only #microsoft.graph.androidCompliancePolicy, the device administrator type, carries the settings
    this helper reads; the property names of the Android Enterprise types are not verified here, so
    their setting fields are left $null rather than guessed. For iOS it is always $true: there is a
    single iOS compliance policy type.

    Used by the iOS and Android device compliance checks.

    Errors are deliberately not caught here. The calling check wraps its logic in try/catch and maps
    401/403 to NotAuthorized and anything else to a skip, so swallowing the exception at this level
    would lose the status code and turn a permission problem into a false security finding.

    .PARAMETER Platform
    The mobile platform whose compliance policies are returned, iOS or Android.

    .EXAMPLE
    Get-MtMobileCompliancePolicy -Platform iOS

    Returns the iOS compliance policies configured in the tenant.

    .EXAMPLE
    Get-MtMobileCompliancePolicy -Platform Android

    Returns the Android compliance policies configured in the tenant, with the Android Enterprise ones
    marked as not evaluated.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param(
        # The mobile platform whose compliance policies are returned.
        [Parameter(Mandatory)]
        [ValidateSet('iOS', 'Android')]
        [string] $Platform
    )

    # The same request and query as the macOS helper, so the two share Invoke-MtGraphRequest's cache.
    $policies = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/deviceCompliancePolicies' `
            -ApiVersion beta -QueryParameters @{ expand = 'assignments' } -ErrorAction Stop)

    # A failed request yields elements with no id. Distinguish that from an empty tenant.
    $usable = @($policies | Where-Object { $_ -and $_.id })
    if ($policies.Count -gt 0 -and $usable.Count -eq 0) {
        Write-Verbose "Compliance policies could not be read; returning null so the caller reports a skip."
        return $null
    }

    # The device administrator type is the only Android type whose property names are verified here.
    $evaluatedType = if ($Platform -eq 'iOS') {
        '#microsoft.graph.iosCompliancePolicy'
    } else {
        '#microsoft.graph.androidCompliancePolicy'
    }
    # Reported but not evaluated, so a caller can tell an Android Enterprise tenant from an empty one.
    $reportedTypes = if ($Platform -eq 'iOS') {
        @()
    } else {
        @('#microsoft.graph.androidWorkProfileCompliancePolicy', '#microsoft.graph.androidDeviceOwnerCompliancePolicy')
    }

    $platformPolicies = @($usable | Where-Object { $_.'@odata.type' -eq $evaluatedType -or $_.'@odata.type' -in $reportedTypes })

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($policy in $platformPolicies) {
        # Inclusion targets only. The collection also carries exclusions, and counting those as
        # coverage reports a policy that reaches nobody as assigned. An assignment with no target
        # type cannot be shown to include anyone, so it is not counted either.
        $assignmentCount = @($policy.assignments | Where-Object {
                $targetType = [string] $_.target.'@odata.type'
                $targetType -and $targetType -notmatch '(^|\.)exclusion'
            }).Count
        $isEvaluated = ($policy.'@odata.type' -eq $evaluatedType)
        # The short form of the @odata.type, for the policy tables in the results.
        $policyType = ($policy.'@odata.type' -replace '^#microsoft\.graph\.', '')

        $row = [ordered]@{
            Id                = $policy.id
            Name              = $policy.displayName
            Platform          = $Platform
            PolicyType        = $policyType
            SettingsEvaluated = $isEvaluated
            AssignmentCount   = $assignmentCount
            IsAssigned        = ($assignmentCount -gt 0)
        }

        if ($Platform -eq 'iOS') {
            $row.BlocksJailbrokenDevices = ($isEvaluated -and $policy.securityBlockJailbrokenDevices -eq $true)
            $row.PasscodeRequired = ($isEvaluated -and $policy.passcodeRequired -eq $true)
            $row.PasscodeBlocksSimple = ($isEvaluated -and $policy.passcodeBlockSimple -eq $true)
            $row.PasscodeMinimumLength = if ($isEvaluated) { $policy.passcodeMinimumLength } else { $null }
            $row.PasscodeInactivityMinutes = if ($isEvaluated) { $policy.passcodeMinutesOfInactivityBeforeLock } else { $null }
            $row.MinimumOsVersion = if ($isEvaluated) { $policy.osMinimumVersion } else { $null }
            $row.RequiresThreatProtection = ($isEvaluated -and $policy.deviceThreatProtectionEnabled -eq $true)
            $row.DefenderRiskScoreLevel = if ($isEvaluated) { $policy.advancedThreatProtectionRequiredSecurityLevel } else { $null }
        } else {
            $row.BlocksRootedDevices = ($isEvaluated -and $policy.securityBlockJailbrokenDevices -eq $true)
            $row.BlocksDeviceAdministrator = ($isEvaluated -and $policy.securityBlockDeviceAdministratorManagedDevices -eq $true)
            $row.UsbDebuggingDisabled = ($isEvaluated -and $policy.securityDisableUsbDebugging -eq $true)
            $row.MinimumSecurityPatchLevel = if ($isEvaluated) { $policy.minAndroidSecurityPatchLevel } else { $null }
            $row.PasswordRequired = ($isEvaluated -and $policy.passwordRequired -eq $true)
            $row.PasswordComplexity = if ($isEvaluated) { $policy.requiredPasswordComplexity } else { $null }
            $row.PasswordMinimumLength = if ($isEvaluated) { $policy.passwordMinimumLength } else { $null }
            $row.PasswordInactivityMinutes = if ($isEvaluated) { $policy.passwordMinutesOfInactivityBeforeLock } else { $null }
            $row.RequiresThreatProtection = ($isEvaluated -and $policy.deviceThreatProtectionEnabled -eq $true)
        }

        $result.Add([pscustomobject] $row)
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
