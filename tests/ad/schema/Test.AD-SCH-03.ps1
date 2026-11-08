function Test-MtAdSchemaVersionEntryCount {
    <#
    .SYNOPSIS
    Reports the Active Directory schema version and all classSchema definitions.

    .DESCRIPTION
    This test retrieves the schema version information from the Active Directory
    schema container and inventories every classSchema object. The schema version
    is not the domain or forest functional level.

    .EXAMPLE
    Test-MtAdSchemaVersionEntryCount

    Returns $true if schema version data is accessible, $false otherwise.
    The test result includes the schema version and all classSchema definitions.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSchemaVersionEntryCount
    #>
    [MaesterTest(
        Id = 'AD-SCH-03',
        Title = 'Schema version and class definitions should be investigated',
        Product = 'ad',
        Feature = 'schema',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Schema/*.objectVersion:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdSchemaVersionEntryCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Schema')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        throw 'Active Directory schema inventory was not returned.'
    }

    $schemaContainer = $adState.SchemaContainer
    $schemaObjects = $adState.SchemaObjects
    if ($null -eq $schemaObjects) { throw 'Active Directory schema objects were not returned.' }

    # Get schema version
    $schemaVersion = if ($schemaContainer -and $schemaContainer.objectVersion) {
        $schemaContainer.objectVersion
    } else {
        $null
    }

    if ($null -eq $schemaVersion) { throw 'Schema container version was not returned.' }
    $versionMap = @{
        13 = 'Windows 2000'
        30 = 'Windows Server 2003'
        31 = 'Windows Server 2003 R2'
        44 = 'Windows Server 2008'
        47 = 'Windows Server 2008 R2'
        56 = 'Windows Server 2012'
        69 = 'Windows Server 2012 R2'
        87 = 'Windows Server 2016'
        88 = 'Windows Server 2019/2022'
        91 = 'Windows Server 2025'
    }
    $osVersion = $versionMap[$schemaVersion]
    if (-not $osVersion) { $osVersion = 'Unknown/custom schema' }

    $classSchemas = @($schemaObjects | Where-Object { $_.ObjectClass -contains 'classSchema' } | Sort-Object Name)
    $result = "| Property | Value |`n| --- | --- |`n"
    $result += "| Schema version | $schemaVersion |`n"
    $result += "| Corresponding Windows Server release | $osVersion |`n"
    $result += "| Schema naming context | $($schemaContainer.DistinguishedName) |`n"
    $result += "| Total schema objects | $(@($schemaObjects).Count) |`n"
    $result += "| classSchema definitions | $($classSchemas.Count) |`n"
    if ($schemaContainer.WhenCreated) { $result += "| Schema created | $($schemaContainer.WhenCreated) |`n" }
    $result += "`n**All classSchema definitions:**`n`n| Name | Distinguished name |`n| --- | --- |`n"
    foreach ($class in $classSchemas) {
        $result += "| $($class.Name) | $($class.DistinguishedName) |`n"
    }
    Add-MtTestResultDetail -Result "Schema version $schemaVersion ($osVersion) and all $($classSchemas.Count) classSchema definitions are shown below. Schema version does not establish functional level.`n`n$result" -Investigate
    return $true
}
