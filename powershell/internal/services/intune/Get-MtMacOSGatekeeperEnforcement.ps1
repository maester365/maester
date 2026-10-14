function Get-MtMacOSGatekeeperEnforcement {
    <#
    .SYNOPSIS
    Retrieves macOS configuration policies that enforce Gatekeeper through the System Policy Control payload.

    .DESCRIPTION
    Gatekeeper can be approached two ways in Intune, and they are different controls:

    - A macOS compliance policy evaluates the device's current Gatekeeper state and marks the device
      non-compliant if it is looser than required. That feeds Conditional Access.
    - A configuration policy pushes the com.apple.systempolicy.control payload to the device, which
      enforces the setting rather than merely observing it.

    This helper covers the second. The macOS endpoint protection template is deprecated, so new
    Gatekeeper configuration is authored in the settings catalog, where the payload appears as a
    group setting collection with the individual keys nested underneath.

    Two keys matter:

    - enableassessment - whether Gatekeeper assessment is on at all. With it disabled, any app runs.
    - allowidentifieddevelopers - whether Developer ID signed apps are permitted in addition to App
      Store apps. Disabling it is the stricter App Store only posture. This is reported as $null when
      the key is absent from the payload, because an omitted key leaves the device's existing setting
      untouched and is not the same as disabling it.

    Returns $null when the configuration policies could not be read, so that callers can report a
    skip rather than a failure.

    Errors are deliberately not caught here. The calling check maps 401/403 to NotAuthorized and
    anything else to a skip, so swallowing the exception at this level would lose the status code and
    turn a permission problem into a false security finding.

    .EXAMPLE
    Get-MtMacOSGatekeeperEnforcement

    Returns the macOS configuration policies that configure the Gatekeeper payload.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    $result = [System.Collections.Generic.List[pscustomobject]]::new()

    $policies = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies?`$filter=platforms has 'macOS'" `
            -ApiVersion beta -Select id, name, templateReference -ErrorAction Stop)

    # A failed request yields elements with no id. Distinguish that from a tenant with no policies.
    $usable = @($policies | Where-Object { $_ -and $_.id })
    if ($policies.Count -gt 0 -and $usable.Count -eq 0) {
        Write-Verbose "macOS configuration policies could not be read; returning null so the caller reports a skip."
        return $null
    }

    foreach ($policy in $usable) {
        $settings = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies('$($policy.id)')/settings?`$top=1000" `
                -ApiVersion beta -ErrorAction Stop)

        # Same guard as the policy list. Without it a failed settings read leaves no setting
        # instances, the policy is skipped silently, and an enforced tenant looks unconfigured.
        $usableSettings = @($settings | Where-Object { $_ -and $_.settingInstance })
        if ($settings.Count -gt 0 -and $usableSettings.Count -eq 0) {
            Write-Verbose "Settings for policy '$($policy.name)' could not be read; returning null so the caller reports a skip."
            return $null
        }

        # Settings catalog nests the payload keys inside groupSettingCollectionValue.children,
        # so flatten one level to reach them.
        $instances = [System.Collections.Generic.List[object]]::new()
        foreach ($setting in $usableSettings) {
            $instance = $setting.settingInstance
            if ($null -eq $instance) { continue }
            $instances.Add($instance)
            foreach ($group in @($instance.groupSettingCollectionValue)) {
                foreach ($child in @($group.children)) {
                    $instances.Add($child)
                }
            }
        }

        $assessment = $instances | Where-Object { $_.settingDefinitionId -eq 'com.apple.systempolicy.control_enableassessment' } | Select-Object -First 1
        if ($null -eq $assessment) { continue }

        # An omitted key is not the same as a disabled one. The MDM payload only applies the
        # keys it contains, so when allowidentifieddevelopers is absent the device keeps its
        # existing setting. Reporting $false here would claim a stricter App Store only posture
        # than the policy actually enforces.
        $identified = $instances | Where-Object { $_.settingDefinitionId -eq 'com.apple.systempolicy.control_allowidentifieddevelopers' } | Select-Object -First 1
        $allowIdentified = if ($null -eq $identified) {
            $null
        } else {
            $identified.choiceSettingValue.value -eq 'com.apple.systempolicy.control_allowidentifieddevelopers_true'
        }

        $assignments = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/configurationPolicies('$($policy.id)')/assignments" `
                -ApiVersion beta -ErrorAction Stop)

        $usableAssignments = @($assignments | Where-Object { $_ -and $_.id })
        if ($assignments.Count -gt 0 -and $usableAssignments.Count -eq 0) {
            Write-Verbose "Assignments for policy '$($policy.name)' could not be read; returning null so the caller reports a skip."
            return $null
        }
        $assignmentCount = $usableAssignments.Count

        $result.Add([pscustomobject]@{
                Id                        = $policy.id
                Name                      = $policy.name
                AssignmentCount           = $assignmentCount
                IsAssigned                = ($assignmentCount -gt 0)
                AssessmentEnabled         = ($assessment.choiceSettingValue.value -eq 'com.apple.systempolicy.control_enableassessment_true')
                AllowIdentifiedDevelopers = $allowIdentified
            })
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
