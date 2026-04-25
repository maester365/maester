function Test-MtAdSchemaVersionEntryCount {
    <#
    .SYNOPSIS
    Counts the number of schema version entries in Active Directory.

    .DESCRIPTION
    This test retrieves the schema version information from the Active Directory
    schema container. The schema version indicates the functional level and
    extensions applied to the directory, with each major Windows Server version
    typically introducing a new schema version.

    .EXAMPLE
    Test-MtAdSchemaVersionEntryCount

    Returns $true if schema version data is accessible, $false otherwise.
    The test result includes the schema version number.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSchemaVersionEntryCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $schemaContainer = $adState.SchemaContainer

    # Get schema version
    $schemaVersion = if ($schemaContainer -and $schemaContainer.objectVersion) {
        $schemaContainer.objectVersion
    } else {
        $null
    }

    # Test passes if we successfully retrieved schema version
    $testResult = $null -ne $schemaVersion

    # Generate markdown results
    if ($testResult) {
        # Map schema versions to Windows Server versions
        $versionMap = @{
            13 = "Windows Server 2000"
            30 = "Windows Server 2003"
            31 = "Windows Server 2003 R2"
            44 = "Windows Server 2008"
            47 = "Windows Server 2008 R2"
            56 = "Windows Server 2012"
            69 = "Windows Server 2012 R2"
            87 = "Windows Server 2016"
            88 = "Windows Server 2019/2022"
        }

        $osVersion = $versionMap[$schemaVersion]
        if (-not $osVersion) {
            $osVersion = "Unknown/Custom Schema"
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Schema Version | $schemaVersion |`n"
        $result += "| Corresponding OS | $osVersion |`n"
        if ($schemaContainer.whenCreated) {
            $result += "| Schema Created | $($schemaContainer.whenCreated) |`n"
        }
        if ($schemaContainer.whenChanged) {
            $result += "| Last Modified | $($schemaContainer.whenChanged) |`n"
        }

        $testResultMarkdown = "Active Directory schema version is $schemaVersion ($osVersion).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory schema version information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
