function Get-MtAppProtectionPolicy {
    <#
    .SYNOPSIS
    Retrieves iOS or Android app protection policies (Intune MAM) with their assignment state.

    .DESCRIPTION
    Queries the Intune app protection policies of the requested mobile platform and returns a
    normalized object per policy carrying the display name, the assignment state, the app scope and
    the settings evaluated by the iOS and Android app protection checks.

    App protection policies are the control that applies to a phone the organization does not
    enroll. A tenant can have a faultless device compliance policy and still let corporate mail be
    copied into a personal app, because compliance evaluates the device and app protection evaluates
    what the app may do with the data. The two are configured in different places and neither
    implies the other.

    One function with a -Platform parameter rather than one function per platform: both platforms
    read the same shape of object from sibling endpoints, and the only part that is easy to get wrong
    is the read-failure contract below. Splitting it in two files would duplicate that contract twice
    and let the copies drift, while the platform-specific part is a property projection. The returned
    shape therefore depends on -Platform, and each call returns a homogeneous set.

    Assignment state is included because an app protection policy that is not assigned to any group
    is never applied to a user, so it cannot satisfy a security control. Two independent signals are
    read: the count of expanded assignments and the server-computed isAssigned property. A policy
    counts as assigned when either says so, and AssignmentSignalsDisagree records the disagreement so
    a caller can surface it instead of silently choosing one.

    Returns $null when the policies could not be read at all, so that callers can report a skip
    rather than a failure. The populated result is emitted with -NoEnumerate because PowerShell
    unrolls collections on output: an empty list would otherwise arrive at the caller as $null and be
    indistinguishable from a read failure. This matters because Invoke-MtGraphRequest surfaces a
    failed call as a non-terminating error with a null result, which collects as a single empty
    element. Treating that as "no policies exist" would produce a false negative: a security finding
    reported purely because the signed-in account lacked permission.

    Thresholds are returned as they come from Graph, with $null meaning "not configured", and are
    never coerced to zero. A caller must guard $null explicitly before comparing: in PowerShell
    $null -le 15 is $true, so a naive threshold check passes a setting that was never configured.
    The two duration settings are also returned parsed into hours and days, because Graph serializes
    Edm.Duration as an ISO 8601 string and 'PT12H' -le 'PT2H' is $true as a string comparison.

    Errors are deliberately not caught here. The calling check wraps its logic in try/catch and maps
    401/403 to NotAuthorized and anything else to a skip, so swallowing the exception at this level
    would lose the status code and turn a permission problem into a false security finding.

    Scope: this reads the targeted app protection policies, deviceAppManagement/iosManagedAppProtections
    and deviceAppManagement/androidManagedAppProtections. The legacy
    deviceAppManagement/defaultManagedAppProtections collection is not read: its entity type derives
    from managedAppProtection rather than targetedManagedAppProtection, so it carries neither
    assignments nor isAssigned and cannot answer the question these checks ask.

    Reading these endpoints requires the DeviceManagementApps.Read.All scope, which is not implied by
    DeviceManagementConfiguration.Read.All.

    Used by the iOS and Android app protection checks.

    .PARAMETER Platform
    The mobile platform whose app protection policies are returned, iOS or Android.

    .EXAMPLE
    Get-MtAppProtectionPolicy -Platform iOS

    Returns the iOS app protection policies configured in the tenant.

    .EXAMPLE
    Get-MtAppProtectionPolicy -Platform Android

    Returns the Android app protection policies configured in the tenant.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param(
        # The mobile platform whose app protection policies are returned.
        [Parameter(Mandatory)]
        [ValidateSet('iOS', 'Android')]
        [string] $Platform
    )

    $relativeUri = if ($Platform -eq 'iOS') {
        'deviceAppManagement/iosManagedAppProtections'
    } else {
        'deviceAppManagement/androidManagedAppProtections'
    }

    # assignments is a containment navigation property on targetedManagedAppProtection and is not
    # returned by default, so it has to be expanded.
    $policies = @(Invoke-MtGraphRequest -RelativeUri $relativeUri `
            -ApiVersion beta -QueryParameters @{ expand = 'assignments' } -ErrorAction Stop)

    # A failed request yields elements with no id. Distinguish that from a tenant with no policies.
    $usable = @($policies | Where-Object { $_ -and $_.id })
    if ($policies.Count -gt 0 -and $usable.Count -eq 0) {
        Write-Verbose "App protection policies could not be read; returning null so the caller reports a skip."
        return $null
    }

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($policy in $usable) {
        $assignmentCount = @($policy.assignments).Count
        $isAssignedFlag = ($policy.isAssigned -eq $true)
        # Either signal is enough. A policy is reported as assigned when the expanded collection or
        # the server-computed property says so, so that a disagreement never produces a finding
        # against a tenant that did assign the policy.
        $isAssigned = ($assignmentCount -gt 0 -or $isAssignedFlag)

        # Graph serializes Edm.Duration as an ISO 8601 string. Parse to a TimeSpan so that callers
        # compare numbers: 'PT12H' -le 'PT2H' is $true as a string comparison, which would read
        # twelve hours as under a two-hour limit. $null stays $null, never zero.
        $offlineBeforeAccessCheckHours = $null
        if ($policy.periodOfflineBeforeAccessCheck) {
            try {
                $offlineBeforeAccessCheckHours = [System.Xml.XmlConvert]::ToTimeSpan([string] $policy.periodOfflineBeforeAccessCheck).TotalHours
            } catch {
                Write-Verbose "Could not parse periodOfflineBeforeAccessCheck '$($policy.periodOfflineBeforeAccessCheck)' on policy '$($policy.displayName)'."
                $offlineBeforeAccessCheckHours = $null
            }
        }

        $offlineBeforeWipeDays = $null
        if ($policy.periodOfflineBeforeWipeIsEnforced) {
            try {
                $offlineBeforeWipeDays = [System.Xml.XmlConvert]::ToTimeSpan([string] $policy.periodOfflineBeforeWipeIsEnforced).TotalDays
            } catch {
                Write-Verbose "Could not parse periodOfflineBeforeWipeIsEnforced '$($policy.periodOfflineBeforeWipeIsEnforced)' on policy '$($policy.displayName)'."
                $offlineBeforeWipeDays = $null
            }
        }

        # The short form of the @odata.type, for the policy tables in the results.
        $policyType = ($policy.'@odata.type' -replace '^#microsoft\.graph\.', '')

        $row = [ordered]@{
            Id                            = $policy.id
            Name                          = $policy.displayName
            Platform                      = $Platform
            PolicyType                    = $policyType
            AssignmentCount               = $assignmentCount
            IsAssignedFlag                = $isAssignedFlag
            IsAssigned                    = $isAssigned
            AssignmentSignalsDisagree     = (($assignmentCount -gt 0) -ne $isAssignedFlag)
            AppGroupType                  = $policy.appGroupType
            DeployedAppCount              = $policy.deployedAppCount

            # Access to the app's data on the device.
            PinRequired                   = ($policy.pinRequired -eq $true)
            MinimumPinLength              = $policy.minimumPinLength
            MaximumPinRetries             = $policy.maximumPinRetries
            SimplePinBlocked              = ($policy.simplePinBlocked -eq $true)
            PinCharacterSet               = $policy.pinCharacterSet
            DisableAppPinIfDevicePinIsSet = ($policy.disableAppPinIfDevicePinIsSet -eq $true)

            # Where the app's data may go.
            OutboundDataTransfer          = $policy.allowedOutboundDataTransferDestinations
            InboundDataTransfer           = $policy.allowedInboundDataTransferSources
            ClipboardSharingLevel         = $policy.allowedOutboundClipboardSharingLevel
            SaveAsBlocked                 = ($policy.saveAsBlocked -eq $true)
            DataBackupBlocked             = ($policy.dataBackupBlocked -eq $true)
            PrintBlocked                  = ($policy.printBlocked -eq $true)

            # Conditional launch.
            MinimumRequiredOsVersion      = $policy.minimumRequiredOsVersion
            MinimumRequiredAppVersion     = $policy.minimumRequiredAppVersion
            OfflineBeforeAccessCheck      = $policy.periodOfflineBeforeAccessCheck
            OfflineBeforeAccessCheckHours = $offlineBeforeAccessCheckHours
            OfflineBeforeWipe             = $policy.periodOfflineBeforeWipeIsEnforced
            OfflineBeforeWipeDays         = $offlineBeforeWipeDays
            MaximumDeviceThreatLevel      = $policy.maximumAllowedDeviceThreatLevel
            ThreatRemediationAction       = $policy.mobileThreatDefenseRemediationAction
            DeviceComplianceRequired      = ($policy.deviceComplianceRequired -eq $true)
        }

        if ($Platform -eq 'iOS') {
            $row.AppDataEncryptionType = $policy.appDataEncryptionType
            $row.MinimumRequiredSdkVersion = $policy.minimumRequiredSdkVersion
            $row.FaceIdBlocked = ($policy.faceIdBlocked -eq $true)
            $row.ThirdPartyKeyboardsBlocked = ($policy.thirdPartyKeyboardsBlocked -eq $true)
        } else {
            $row.EncryptAppData = ($policy.encryptAppData -eq $true)
            # Reads the flag, not only the level: this one can switch the encryption above off.
            $row.AppEncryptionDisabledByDeviceEncryption = ($policy.disableAppEncryptionIfDeviceEncryptionIsEnabled -eq $true)
            $row.ScreenCaptureBlocked = ($policy.screenCaptureBlocked -eq $true)
            $row.DeviceAttestationType = $policy.requiredAndroidSafetyNetDeviceAttestationType
            $row.ActionIfAttestationFailed = $policy.appActionIfAndroidSafetyNetDeviceAttestationFailed
            $row.DeviceLockRequired = ($policy.deviceLockRequired -eq $true)
            $row.MinimumRequiredPatchVersion = $policy.minimumRequiredPatchVersion
        }

        $result.Add([pscustomobject] $row)
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
