function Test-MtAdRecycleBinEnabledPaths {
    <#
    .SYNOPSIS
    Counts Active Directory paths where the Recycle Bin is enabled.

    .DESCRIPTION
    This test examines Active Directory optional features for any feature related to the Recycle Bin
    and counts the configured enabled scopes/paths.

    .EXAMPLE
    Test-MtAdRecycleBinEnabledPaths

    Returns $true if optional feature data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdRecycleBinEnabledPaths
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-CFG-05',
        Title = 'Recycle bin enabled paths should be retrievable',
        Severity = 'Info',
        Category = 'Active Directory - Configuration',
        Product = 'Active Directory',
        Tag = 'AD.Config',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdRecycleBinEnabledPaths"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('OptionalFeatures')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $optionalFeatures = $adState.OptionalFeatures
    $recycleBinFeatures = @($optionalFeatures | Where-Object {
            $_.Name -like "*Recycle Bin*" -and $_.IsEnabled
        })

    $enabledScopes = @(
        $recycleBinFeatures | ForEach-Object { $_.DistinguishedName }
    ) | Where-Object { $null -ne $_ }

    $enabledPathCount = ($enabledScopes | Measure-Object).Count

    # Test passes if we successfully retrieved optional feature data
    $testResult = $null -ne $adState.OptionalFeatures

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Recycle Bin Feature Matches | $($recycleBinFeatures.Count) |" + "`n"
        $result += "| Recycle Bin Enabled Path Count | $enabledPathCount |" + "`n"

        if ($enabledPathCount -gt 0) {
            $result += "| Enabled Scopes | $($enabledScopes -join ', ') |" + "`n"
        }

        $testResultMarkdown = "Active Directory Recycle Bin enabled paths have been analyzed. Found $enabledPathCount enabled scope(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory optional features for Recycle Bin evaluation. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
