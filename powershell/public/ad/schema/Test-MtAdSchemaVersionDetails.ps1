function Test-MtAdSchemaVersionDetails {
    <#
    .SYNOPSIS
    Provides detailed Active Directory schema version information.

    .DESCRIPTION
    This test retrieves comprehensive schema version details from the Active Directory
    schema container, including the object version number, creation date, and last
    modification date. This information helps identify the directory's schema level
    and track when schema updates occurred.

    .EXAMPLE
    Test-MtAdSchemaVersionDetails

    Returns $true if schema version data is accessible, $false otherwise.
    The test result includes detailed schema version information.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSchemaVersionDetails
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
    $schemaObjects = $adState.SchemaObjects

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

        # Calculate object class distribution
        $classDistribution = $schemaObjects | Group-Object objectClass | Select-Object Name, Count | Sort-Object Count -Descending

        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Schema Version | $schemaVersion |`n"
        $result += "| Corresponding OS | $osVersion |`n"
        $result += "| Schema Naming Context | $($schemaContainer.DistinguishedName) |`n"
        if ($schemaContainer.whenCreated) {
            $result += "| Schema Created | $($schemaContainer.whenCreated) |`n"
        }
        if ($schemaContainer.whenChanged) {
            $result += "| Last Modified | $($schemaContainer.whenChanged) |`n"
        }
        if ($schemaContainer.ObjectGUID) {
            $result += "| Object GUID | $($schemaContainer.ObjectGUID) |`n"
        }
        $result += "| Total Schema Objects | $(($schemaObjects | Measure-Object).Count) |`n`n"

        $result += "**Schema Object Classes:**`n`n"
        $result += "| Object Class | Count |`n"
        $result += "| --- | --- |`n"
        foreach ($class in ($classDistribution | Select-Object -First 10)) {
            $result += "| $($class.Name) | $($class.Count) |`n"
        }

        $testResultMarkdown = "Active Directory schema version details. The directory is running schema version $schemaVersion ($osVersion).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory schema version information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
