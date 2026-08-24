function Test-MtMacOSLAPSConfiguration {
    <#
    .SYNOPSIS
    Ensure macOS Automated Device Enrollment profiles configure a managed local administrator account with password rotation.

    .DESCRIPTION
    The Intune implementation of macOS LAPS is not a policy. Unlike Windows LAPS, which is a settings
    catalog policy, macOS LAPS is configured on the Automated Device Enrollment (ADE) profile itself,
    on the Account Settings tab. There is no policy object to look for.

    When configured, each device enrolling through that ADE profile is provisioned with a local
    administrator account whose 15-character password is generated, encrypted and stored by Intune,
    and rotated automatically. Administrators with the right RBAC permission can retrieve or manually
    rotate it.

    Without it, macOS fleets are typically built with a single shared local administrator password
    baked into an image or a provisioning script. That credential is identical on every Mac, is never
    rotated, and is the classic lateral-movement primitive: one recovered password grants local
    administrator access to the entire fleet.

    Two properties matter beyond mere presence:

    - A rotation setting must exist. An admin account with no rotation configuration is a static
      password, which defeats the purpose.
    - Rotate on retrieval should be enabled, so the password is rotated after an administrator views
      it. Without it, every past viewing remains a valid credential indefinitely.

    Note that macOS LAPS only applies to devices that enroll through ADE after a factory reset.
    Existing devices must be re-enrolled to be covered, so a passing result here describes newly
    enrolled devices rather than the whole estate.

    .EXAMPLE
    Test-MtMacOSLAPSConfiguration

    Returns true if at least one macOS ADE profile provisions a managed local admin account with password rotation.

    .LINK
    https://maester.dev/docs/commands/Test-MtMacOSLAPSConfiguration
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose "Querying macOS Automated Device Enrollment profiles..."
        $profiles = Get-MtMacOSEnrollmentProfile
        if ($null -eq $profiles) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        $portalLink = 'https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/EnrollmentMenu/~/appleEnrollment'

        if ($profiles.Count -eq 0) {
            $testResultMarkdown = "No macOS Automated Device Enrollment profiles were found in Intune.`n`n"
            $testResultMarkdown += "macOS LAPS is configured on an ADE profile, so it requires Apple Business Manager to be connected "
            $testResultMarkdown += "and at least one macOS enrollment profile to exist. "
            $testResultMarkdown += "Connect Apple Business Manager and create a macOS enrollment profile with a local administrator account."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $compliant = @($profiles | Where-Object { $_.HasAdminAccount -and $_.HasPasswordRotation })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($profiles.Count) macOS Automated Device Enrollment profile/profiles in Intune.`n`n"
        $testResultMarkdown += "| Profile | Token | Managed admin account | Password rotation | Rotate on retrieval |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- |`n"
        foreach ($enrollmentProfile in $profiles) {
            $adminState = if ($enrollmentProfile.HasAdminAccount) { 'Configured' } else { 'Not configured' }
            if ($enrollmentProfile.HasPasswordRotation) {
                $rotationState = if ($enrollmentProfile.AutoRotationPeriodInDays) { "Every $($enrollmentProfile.AutoRotationPeriodInDays) days" } else { 'Enabled' }
            } else {
                $rotationState = 'Not configured'
            }
            $retrievalState = if ($enrollmentProfile.RotateOnRetrieval) { 'Yes' } else { 'No' }
            $testResultMarkdown += "| $($enrollmentProfile.Name) | $($enrollmentProfile.TokenName) | $adminState | $rotationState | $retrievalState |`n"
        }

        $testResultMarkdown += "`n[View Apple enrollment profiles in the Intune admin center]($portalLink)`n"

        # A profile that provisions an admin account but configures no rotation creates a
        # static local administrator password on every device enrolled through it. That is the
        # exact risk this check exists to catch, so it is evaluated regardless of whether some
        # other profile satisfies the check.
        $staticPassword = @($profiles | Where-Object { $_.HasAdminAccount -and -not $_.HasPasswordRotation })

        if ($testResult) {
            $testResultMarkdown += "`nAt least one macOS enrollment profile provisions a managed local administrator account with password rotation."

            if ($staticPassword.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Warning:** $($staticPassword.Count) profile/profiles provision a local administrator "
                $testResultMarkdown += "account with **no password rotation** configured. Devices enrolled through those profiles "
                $testResultMarkdown += "receive a static local administrator password that Intune never rotates."
            }

            $noRetrievalRotation = @($compliant | Where-Object { -not $_.RotateOnRetrieval })
            if ($noRetrievalRotation.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($noRetrievalRotation.Count) profile/profiles do not rotate the password after it is retrieved. "
                $testResultMarkdown += "Every previous retrieval therefore remains a valid credential until the next scheduled rotation."
            }

            $testResultMarkdown += "`n`n> macOS LAPS applies only to devices that enroll through Automated Device Enrollment after a factory reset. "
            $testResultMarkdown += "Devices enrolled before the profile was configured are not covered until they are re-enrolled."
        } else {
            if ($staticPassword.Count -gt 0) {
                $testResultMarkdown += "`n$($staticPassword.Count) profile/profiles configure a local administrator account but **no password rotation**, "
                $testResultMarkdown += "so the account password is static. Configure an admin account password rotation period."
            } else {
                $testResultMarkdown += "`nNo macOS enrollment profile provisions a managed local administrator account. "
                $testResultMarkdown += "Local administrator credentials on these devices are not managed or rotated by Intune."
            }
        }

        # Partial compliance: the check is satisfied by one profile while another actively
        # provisions a static password. Flag for manual review rather than reporting a clean
        # pass, which would give false assurance across the whole enrollment estate.
        if ($testResult -and $staticPassword.Count -gt 0) {
            Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        } else {
            if ($testResult) {
                $testResultMarkdown = "Well done. $testResultMarkdown"
            }
            Add-MtTestResultDetail -Result $testResultMarkdown
        }
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
