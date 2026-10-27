function Test-MtAdGpoNoAuthenticatedUsersDetails {
    <#
    .SYNOPSIS
    Returns details of GPO reports without Authenticated Users.

    .DESCRIPTION
    This test retrieves GPO state data and returns a markdown table listing the GPO
    reports where Authenticated Users are not present.

    .EXAMPLE
    Test-MtAdGpoNoAuthenticatedUsersDetails

    Returns $true when no GPO reports are missing Authenticated Users, otherwise $false.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoAuthenticatedUsersDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-GPOREP-04',
        Title = 'GPOs without authenticated users details should be retrievable',
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

    Write-Verbose "Starting Test-MtAdGpoNoAuthenticatedUsersDetails"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no authenticated users details"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # HasAuthenticatedUsers is $null when the security descriptor of a GPO could not be read: unknown, not missing.
    $reportsWithNoAuthenticatedUsers = @($gpoReports | Where-Object { $false -eq $_.HasAuthenticatedUsers })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.HasAuthenticatedUsers })
    $notEvaluatedCount = $reportsNotEvaluated.Count

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $noAuthenticatedUsersCount = ($reportsWithNoAuthenticatedUsers | Measure-Object).Count
    $testResult = $noAuthenticatedUsersCount -eq 0

    $table = "| GPO Name | HasAuthenticatedUsers |" + "`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in @(@($reportsWithNoAuthenticatedUsers) + @($reportsNotEvaluated) | Sort-Object Name)) {
        $name = if ($null -ne $report.Name) { [string]$report.Name } else { '' }
        $name = $name -replace '\|', '\\&#124;'

        $hasAuthenticatedUsers = $report.HasAuthenticatedUsers
        if ($null -eq $hasAuthenticatedUsers) { $hasAuthenticatedUsers = 'Not evaluated (permissions could not be read)' }
        $table += "| $name | $hasAuthenticatedUsers |" + "`n"
    }

    # Nothing was flagged, but a GPO whose permissions could not be read is not a pass.
    $needsInvestigation = $testResult -and $notEvaluatedCount -gt 0
    $recommendation = if ($needsInvestigation) {
        "ℹ️ No GPO reports were found missing Authenticated Users among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    } elseif ($testResult) {
        '✅ No GPO reports were found missing Authenticated Users.'
    } else {
        "⚠️ GPO reports were found missing Authenticated Users ($noAuthenticatedUsersCount)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoAuthenticatedUsersDetails"
    return $testResult
}
