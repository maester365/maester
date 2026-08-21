function Test-MtMacOSSystemIntegrityProtection {
    <#
    .SYNOPSIS
    Ensure at least one assigned macOS compliance policy requires System Integrity Protection.

    .DESCRIPTION
    System Integrity Protection (SIP) is a macOS kernel-level protection that stops even the root
    user from modifying protected system files and processes, or attaching a debugger to system
    binaries. It is enabled by default.

    SIP cannot be configured or enforced by an MDM. It is toggled from macOS Recovery on the device
    itself. What Intune can do is require it as a compliance condition, so a device with SIP
    disabled is marked non-compliant and can then be blocked by Conditional Access.

    That distinction matters. Disabling SIP takes a deliberate, physically present action, and it is
    how unsigned kernel extensions get loaded, how security agents such as Microsoft Defender for
    Endpoint are tampered with, and how persistence is established in protected locations. Without a
    compliance rule, Intune reports such a device as healthy.

    This test passes if at least one macOS compliance policy that is assigned to a group sets
    "Require a system integrity protection" to Require. Policies with no assignment are reported but
    do not count towards a pass, because an unassigned compliance policy is never evaluated.

    .EXAMPLE
    Test-MtMacOSSystemIntegrityProtection

    Returns true if at least one assigned macOS compliance policy requires System Integrity Protection.

    .LINK
    https://maester.dev/docs/commands/Test-MtMacOSSystemIntegrityProtection
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose "Querying macOS compliance policies..."
        $policies = Get-MtMacOSCompliancePolicy
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        $portalLink = 'https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance'

        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No macOS compliance policies were found in Intune.`n`n"
            $testResultMarkdown += "Without a macOS compliance policy, a Mac with System Integrity Protection disabled is still reported as compliant. "
            $testResultMarkdown += "Create a macOS compliance policy and set **Require a system integrity protection** to **Require**."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $compliant = @($policies | Where-Object { $_.RequiresSip -and $_.IsAssigned })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) macOS compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Requires SIP | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $sipState = if ($policy.RequiresSip) { 'Required' } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $sipState | $assignmentState |`n"
        }

        $testResultMarkdown += "`n[View compliance policies in the Intune admin center]($portalLink)`n"

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned macOS compliance policy requires System Integrity Protection."
            $gaps = @($policies | Where-Object { -not $_.RequiresSip -and $_.IsAssigned })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not require System Integrity Protection. "
                $testResultMarkdown += "Devices scoped only to those policies are not evaluated for SIP."
            }
        } else {
            $unassigned = @($policies | Where-Object { $_.RequiresSip -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies require System Integrity Protection but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your macOS device or user groups."
            } else {
                $testResultMarkdown += "`nNo macOS compliance policy requires System Integrity Protection. "
                $testResultMarkdown += "A Mac with SIP disabled is reported as compliant and keeps access to corporate resources."
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
