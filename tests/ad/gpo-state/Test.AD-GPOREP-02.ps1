function Test-MtAdGpoNoPermissionsDetails {
    <#
    .SYNOPSIS
    Returns details of GPO reports missing permissions.

    .DESCRIPTION
    This test retrieves GPO state data and returns a markdown table listing the GPO
    reports where permissions are not present.

    .EXAMPLE
    Test-MtAdGpoNoPermissionsDetails

    Returns $true when no GPOs are missing permissions, otherwise $false.
    The test result includes a markdown table with the affected GPO report names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoPermissionsDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-GPOREP-02',
        Title = 'No GPOs should be missing permissions',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'access-control',
        ResourceType = 'GroupPolicy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoNoPermissionsDetails"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no permissions details"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # PermissionsPresent is $null when the security descriptor of a GPO could not be read: unknown, not missing.
    $reportsWithNoPermissions = @($gpoReports | Where-Object { $false -eq $_.PermissionsPresent })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.PermissionsPresent })
    $notEvaluatedCount = $reportsNotEvaluated.Count

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $noPermissionsCount = ($reportsWithNoPermissions | Measure-Object).Count
    $testResult = $noPermissionsCount -eq 0

    $table = "| GPO Name | PermissionsPresent |" + "`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in @(@($reportsWithNoPermissions) + @($reportsNotEvaluated) | Sort-Object Name)) {
        $name = if ($null -ne $report.Name) { [string]$report.Name } else { '' }
        $name = $name -replace '\|', '\\&#124;'

        $permissionsPresent = $report.PermissionsPresent
        if ($null -eq $permissionsPresent) { $permissionsPresent = 'Not evaluated (permissions could not be read)' }
        $table += "| $name | $permissionsPresent |" + "`n"
    }

    # Nothing was flagged, but a GPO whose permissions could not be read is not a pass.
    $needsInvestigation = $testResult -and $notEvaluatedCount -gt 0
    $recommendation = if ($needsInvestigation) {
        "ℹ️ No GPO reports were found with missing permissions among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    } elseif ($testResult) {
        '✅ No GPO reports were found with missing permissions.'
    } else {
        "⚠️ GPO reports were found with missing permissions ($noPermissionsCount)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoPermissionsDetails"
    return $testResult
}
