function Test-MtAdSchemaModificationYearCount {
    <#
    .SYNOPSIS
    Counts the number of years with Active Directory schema object creation.

    .DESCRIPTION
    This test groups schema objects by whenCreated. It describes creation years,
    not subsequent schema object edits or an audit history of changes.

    .EXAMPLE
    Test-MtAdSchemaModificationYearCount

    Reports creation-year counts and schema objects grouped by creation year.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSchemaModificationYearCount
    #>
    [MaesterTest(
        Id = 'AD-SCH-01',
        Title = 'Schema creation years and objects should be investigated',
        Product = 'ad',
        Feature = 'schema',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Schema/*:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdSchemaModificationYearCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Schema')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        throw 'Active Directory schema inventory was not returned.'
    }

    $schemaObjects = $adState.SchemaObjects
    if ($null -eq $schemaObjects) { throw 'Active Directory schema objects were not returned.' }

    $datedObjects = @($schemaObjects | Where-Object { $null -ne $_.WhenCreated })
    $years = @($datedObjects | Group-Object { $_.WhenCreated.Year } | Sort-Object Name)
    $result = "| Metric | Value |`n| --- | --- |`n"
    $result += "| Total schema objects | $(@($schemaObjects).Count) |`n"
    $result += "| Objects with creation date | $($datedObjects.Count) |`n"
    $result += "| Creation years | $($years.Count) |`n`n"
    $result += "| Year | Object count |`n| --- | --- |`n"
    foreach ($year in $years) {
        $result += "| $($year.Name) | $($year.Count) |`n"
    }
    $result += "`n**Schema objects by creation year:**`n`n| Year | Object name | Distinguished name |`n| --- | --- | --- |`n"
    foreach ($object in ($datedObjects | Sort-Object WhenCreated, Name)) {
        $result += "| $($object.WhenCreated.Year) | $($object.Name) | $($object.DistinguishedName) |`n"
    }
    if ($datedObjects.Count -lt @($schemaObjects).Count) {
        $result += "`n$(@($schemaObjects).Count - $datedObjects.Count) object(s) lack a creation date and are excluded from the year breakdown."
    }
    Add-MtTestResultDetail -Result "Schema object creation dates span $($years.Count) year(s). Creation dates do not reveal subsequent schema edits.`n`n$result" -Investigate
    return $true
}
