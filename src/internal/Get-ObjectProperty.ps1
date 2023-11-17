<#
.SYNOPSIS
    Get object property value.
.EXAMPLE
    PS C:\>$object = New-Object psobject -Property @{ title = 'title value' }
    PS C:\>$object | Get-ObjectProperty -Property 'title'
    Get value of object property named title.
.EXAMPLE
    PS C:\>$object = New-Object psobject -Property @{ lvl1 = (New-Object psobject -Property @{ nextLevel = 'lvl2 data' }) }
    PS C:\>Get-ObjectProperty $object -Property 'lvl1', 'nextLevel'
    Get value of nested object property named nextLevel.
.INPUTS
    System.Collections.Hashtable
    System.Management.Automation.PSObject
#>
function Get-ObjectProperty {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        # Object containing property values
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObjects,
        # Name of property. Specify an array of property names to tranverse nested objects.
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]] $Property
    )

    process {
        foreach ($InputObject in $InputObjects) {
            for ($iProperty = 0; $iProperty -lt $Property.Count; $iProperty++) {
                ## Get property value
                if ($InputObject -is [hashtable]) {
                    if ($InputObject.ContainsKey($Property[$iProperty])) {
                        $PropertyValue = $InputObject[$Property[$iProperty]]
                    }
                    else { $PropertyValue = $null}
                }
                else {
                    $PropertyValue = Select-Object -InputObject $InputObject -ExpandProperty $Property[$iProperty] -ErrorAction SilentlyContinue
                }
                ## Check for more nested properties
                if ($iProperty -lt $Property.Count - 1) {
                    $InputObject = $PropertyValue
                    if ($null -eq $InputObject) { break }
                }
                else {
                    Write-Output $PropertyValue
                }
            }
        }
    }
}
