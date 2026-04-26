function Test-MtAdGpoUnlinkedDetails {
    <#
    .SYNOPSIS
    Returns details of unlinked Group Policy Objects (GPOs) in Active Directory.

    .DESCRIPTION
    This test analyzes the Group Policy Objects (GPOs) in Active Directory and returns a list of
    unlinked GPOs (including the GPO DisplayName, CreationTime, and ModificationTime).

    Knowing which GPOs are unlinked helps identify policies that are no longer in use. Reviewing
    and removing unused GPOs reduces operational complexity and can help reduce attack surface.

    .EXAMPLE
    Test-MtAdGpoUnlinkedDetails

    Returns $true if GPO data is accessible, $false otherwise.
    The test result includes a markdown table with the details of unlinked GPOs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoUnlinkedDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD GPO state data (uses cached data if available)
    $gpoState = Get-MtADGpoState

    # If unable to retrieve GPO data, skip the test
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpos = $gpoState.GPOs
    if ($null -eq $gpos) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory Group Policy Objects. Ensure you have appropriate permissions and that the Group Policy Management Console is installed.'
        return $false
    }

    # Collect GPO IDs that appear in GPOLinks (gPLink) across the collected AD containers.
    # Get-MtADGpoState currently retrieves GPOLinks from configuration naming context.
    $linkedGpoIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $gpLinks = $gpoState.GPOLinks
    if ($gpLinks) {
        foreach ($linkObject in $gpLinks) {
            $gPLinkValue = $linkObject.gPLink
            if ([string]::IsNullOrWhiteSpace($gPLinkValue)) {
                continue
            }

            # gPLink contains one or more entries like:
            # LDAP://CN=...,CN=Policies,CN=System,DC=example,DC=com;{GPO-GUID};0
            foreach ($match in ([regex]::Matches($gPLinkValue, '\{([0-9a-fA-F-]{36})\}'))) {
                $guid = $match.Groups[1].Value
                if (-not [string]::IsNullOrWhiteSpace($guid)) {
                    $linkedGpoIds.Add($guid) | Out-Null
                }
            }
        }
    }

    # Identify unlinked/orphaned GPOs.
    $unlinkedGpos = @()
    foreach ($gpo in $gpos) {
        $gpoId = if ($null -ne $gpo.Id) { [string]$gpo.Id } else { $null }

        # Optional fallback: some environments may surface unlinked wording in GpoStatus.
        $statusText = if ($null -ne $gpo.GpoStatus) { [string]$gpo.GpoStatus } else { $null }
        $looksUnlinked = $false
        if ($statusText -and ($statusText -match 'Unlinked|No links|Not linked')) {
            $looksUnlinked = $true
        }

        $isLinked = $false
        if ($gpoId) {
            $isLinked = $linkedGpoIds.Contains($gpoId)
        }

        if (-not $isLinked -or $looksUnlinked) {
            $unlinkedGpos += $gpo
        }
    }

    $unlinkedGpoCount = @($unlinkedGpos).Count

    # Security intent: pass only when no unlinked/orphaned GPOs exist.
    $testResult = $unlinkedGpoCount -eq 0

    # Build the markdown table with details of unlinked GPOs
    $table = "| GPO DisplayName | CreationTime | ModificationTime |`n"
    $table += '| --- | --- | --- |' + "`n"

    foreach ($gpo in @($unlinkedGpos | Sort-Object DisplayName)) {
        $displayName = [string]$gpo.DisplayName
        $displayName = $displayName -replace '\|', '\\&#124;'

        $creationTime = $null
        if ($null -ne $gpo.CreationTime) {
            $creationTime = ([datetime]$gpo.CreationTime).ToString('yyyy-MM-dd HH:mm:ss')
        } else {
            $creationTime = ''
        }

        $modificationTime = $null
        if ($null -ne $gpo.ModificationTime) {
            $modificationTime = ([datetime]$gpo.ModificationTime).ToString('yyyy-MM-dd HH:mm:ss')
        } else {
            $modificationTime = ''
        }

        $table += "| $displayName | $creationTime | $modificationTime |`n"
    }

    $recommendation = if ($testResult) {
        '✅ Unlinked/orphaned GPOs have not been found. Active Directory Group Policy Objects have been analyzed successfully.'
    } else {
        "⚠️ Unlinked/orphaned GPOs were found ($unlinkedGpoCount). Review these policies for removal to reduce GPO sprawl and lower risk from unused (and potentially misconfigured) policies."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



